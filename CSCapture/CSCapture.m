#import "CSCapture.h"

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>


typedef struct __BlobIndex {
    uint32_t type;                   /* type of entry */
    uint32_t offset;                 /* offset of entry */
} CS_BlobIndex;

typedef struct __SuperBlob {
    uint32_t magic;                  /* magic number */
    uint32_t length;                 /* total length of SuperBlob */
    uint32_t count;                  /* number of index entries following */
    CS_BlobIndex index[];                 /* (count) entries */
    /* followed by Blobs in no particular order as indicated by offsets in index */
} CS_SuperBlob;

typedef struct __Blob {
    uint32_t magic;
    uint32_t length;
    uint8_t bytes[];
} CS_Blob;

typedef enum __Magic {
    CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0,
    CSMAGIC_BLOBWRAPPER = 0xfade0b01
} CS_Magic;



@interface CSCapture () {
    const struct mach_header *_mach_hdr;
}

@end



@implementation CSCapture

+ (const struct mach_header *)machHeaderByImageNumber:(uint32_t)image_no
{
    return _dyld_get_image_header(image_no);
}

+ (NSData *)binaryCodesignBlob
{
    CSCapture *capture = [[CSCapture alloc] init];
    return [capture binaryCodesignBlob];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _mach_hdr = [CSCapture machHeaderByImageNumber:0];
    }
    
    return self;
}

- (NSData *)binaryCodesignBlob
{
    return [self codesignBlobByMagicType:CSMAGIC_BLOBWRAPPER];
}

- (BOOL)is64Bit
{
    return _mach_hdr->magic == MH_MAGIC_64 || _mach_hdr->magic == MH_CIGAM_64;
}

- (NSData *)codesignBlobByMagicType:(CS_Magic)magic {
    uint32_t command_count = [self loadCommandCountByType:LC_CODE_SIGNATURE];
    if (command_count > 0) {
        const struct load_command **load_commands = [self copyLoadCommandsByType:LC_CODE_SIGNATURE];
        
        for (int i = 0; i < command_count; i++) {
            const struct linkedit_data_command *data_command = (const struct linkedit_data_command *) load_commands[i];
            uint32_t signature_offset = data_command->dataoff;

            uint8_t *lc_code_signature = (uint8_t *) _mach_hdr + signature_offset;
            CS_SuperBlob *super_blob = (CS_SuperBlob *) lc_code_signature;
            if (ntohl(super_blob->magic) == CSMAGIC_EMBEDDED_SIGNATURE) {
                uint32_t blob_count = ntohl(super_blob->count);
                for (int j = 0; j < blob_count; j++) {
                    uint32_t blob_offset = ntohl(super_blob->index[j].offset);
                    uint8_t *blob_bytes = lc_code_signature + blob_offset;
                    CS_Blob *blob = (CS_Blob *)blob_bytes;
                    uint32_t blob_magic = ntohl(blob->magic);
                    if (blob_magic == magic) {
                        uint32_t signature_len = ntohl(blob->length) - 8;
                        return [NSData dataWithBytes:blob->bytes length:signature_len];
                    }
                }
            }
        }
    }

    return NULL;
}

- (uint32_t)loadCommandCountByType:(uint32_t)loadCommandType
{
    uint32_t count = 0;
    
    uint32_t commandCount = [self loadCommandCount];
    const struct load_command **loadCommands = [self copyLoadCommands];
    for (int i = 0; i < commandCount; i++) {
        const struct load_command *cmd = loadCommands[i];
        if (cmd->cmd == loadCommandType) {
            count++;
        }
    }
    free(loadCommands);
    
    return count;
}

- (uint32_t)loadCommandCount
{
    if (_mach_hdr == NULL) return 0;

    return _mach_hdr->ncmds;
}

- (void *)firstLoadCommandAddress
{
    if (_mach_hdr == NULL) return NULL;
    
    size_t header_size;
    if ([self is64Bit]) {
        header_size = sizeof(struct mach_header_64);
    } else {
        header_size = sizeof(struct mach_header);
    }
    
    return (void *)_mach_hdr + header_size;
}

- (const struct load_command **)copyLoadCommands
{
    uint32_t command_count = [self loadCommandCount];
    void *next_record = [self firstLoadCommandAddress];

    const struct load_command **load_commands = malloc(command_count * sizeof(struct load_command *));
    for (int i = 0; i < command_count; i++) {
        const struct load_command *cmd = (struct load_command *)next_record;
        load_commands[i] = cmd;
        next_record += cmd->cmdsize;
    }

    return load_commands;
}

- (const struct load_command **)copyLoadCommandsByType:(uint32_t)loadCommandType
{
    uint32_t command_count = [self loadCommandCount];
    const struct load_command **load_commands = [self copyLoadCommands];
    uint32_t type_count = [self loadCommandCountByType:loadCommandType];
    const struct load_command **type_commands = malloc(type_count * sizeof(struct load_command *));
    uint32_t type_index = 0;
    for (int i = 0; i < command_count; i++) {
        const struct load_command *cmd = load_commands[i];
        if (cmd->cmd == loadCommandType) {
            type_commands[type_index] = cmd;
            type_index++;
        }
    }
    free(load_commands);
    
    return type_commands;
}

@end
