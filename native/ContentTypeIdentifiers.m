#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <stdio.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableDictionary<NSString *, NSArray<NSString *> *> *result = [NSMutableDictionary dictionary];
        for (int index = 1; index < argc; index++) {
            NSString *extension = [NSString stringWithUTF8String:argv[index]];
            NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
            NSArray<UTType *> *types = [UTType typesWithTag:extension
                                                  tagClass:UTTagClassFilenameExtension
                                          conformingToType:nil];
            for (UTType *type in types) {
                if (type.identifier.length > 0 && ![identifiers containsObject:type.identifier]) {
                    [identifiers addObject:type.identifier];
                }
            }
            UTType *preferredType = [UTType typeWithFilenameExtension:extension];
            if (preferredType.identifier.length > 0 && ![identifiers containsObject:preferredType.identifier]) {
                [identifiers addObject:preferredType.identifier];
            }
            result[extension] = identifiers;
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingSortedKeys error:&error];
        if (!data) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        fwrite(data.bytes, 1, data.length, stdout);
        fputc('\n', stdout);
    }
    return 0;
}
