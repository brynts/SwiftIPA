#import "ZSignBridge.h"

#if SWIFTIPA_HAS_ZSIGN
#include "bundle.h"
#include "openssl.h"
#include <list>
#include <vector>
#include <QuartzCore/QuartzCore.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/pkcs12.h>
#include <openssl/rsa.h>
#include <openssl/evp.h>
#include <openssl/x509v3.h>
#include <openssl/asn1.h>
#include <openssl/bio.h>
#include <time.h>
#endif

@implementation ZSignResult
@end

@implementation ZSignOptions
@end

@interface ZSignBridge ()
+ (nullable NSDate *)dateFromCertificateData:(NSData *)certificateData notAfter:(BOOL)wantsNotAfter;
@end

@implementation ZSignBridge

+ (BOOL)isEngineAvailable {
#if SWIFTIPA_HAS_ZSIGN
    return YES;
#else
    return NO;
#endif
}

+ (ZSignResult *)signAppFolderAtPath:(NSString *)folderPath options:(ZSignOptions *)options {
    ZSignResult *result = [ZSignResult new];

#if SWIFTIPA_HAS_ZSIGN
    CFTimeInterval started = CACurrentMediaTime();

    ZSignAsset asset;
    bool prepared = asset.Init(
        std::string([options.p12Path UTF8String] ?: ""),
        std::string([options.p12Path UTF8String] ?: ""),
        std::string([options.provisionPath UTF8String] ?: ""),
        std::string(options.entitlementsPath ? [options.entitlementsPath UTF8String] : ""),
        std::string([options.p12Password UTF8String] ?: ""),
        options.adhoc,
        true,
        false
    );

    if (!prepared) {
        result.code = ZSignResultCodeInvalidCertificate;
        result.message = @"zsign could not load the certificate, private key or provisioning profile.";
        return result;
    }

    ZBundle bundle;
    bundle.m_bEnableDocuments = false;
    bundle.m_strMinVersion = std::string(options.minimumOSVersion ? [options.minimumOSVersion UTF8String] : "");
    bundle.m_strIconFile = std::string(options.iconPath ? [options.iconPath UTF8String] : "");
    bundle.m_bRemoveExtensions = options.removeExtensions;
    bundle.m_bRemoveWatchApp = options.removeWatchApp;
    bundle.m_bRemoveUISupportedDevices = options.removeUISupportedDevices;
    bundle.m_bInjectExtensions = false;

    std::vector<std::string> dylibs;
    for (NSString *path in options.dylibPathsToInject) {
        dylibs.push_back(std::string([path UTF8String]));
    }
    std::vector<std::string> removedDylibs;
    for (NSString *name in options.dylibNamesToRemove) {
        removedDylibs.push_back(std::string([name UTF8String]));
    }

    bool signed_ = bundle.SignFolder(
        &asset,
        std::string([folderPath UTF8String] ?: ""),
        std::string(options.bundleIdentifier ? [options.bundleIdentifier UTF8String] : ""),
        std::string(options.bundleShortVersion ? [options.bundleShortVersion UTF8String] : ""),
        std::string(options.bundleName ? [options.bundleName UTF8String] : ""),
        dylibs,
        removedDylibs,
        options.forceSign,
        options.weakInject,
        true,
        options.removeProvisionAfterSigning
    );

    result.duration = CACurrentMediaTime() - started;

    if (!signed_) {
        result.code = ZSignResultCodeSigningFailed;
        result.message = @"zsign failed to sign the app bundle. Check the certificate, provisioning profile and entitlements.";
        return result;
    }

    result.code = ZSignResultCodeSuccess;
    return result;
#else
    (void)folderPath;
    (void)options;
    result.code = ZSignResultCodeEngineUnavailable;
    result.message = @"The zsign engine is not vendored in this build. Run Scripts/fetch-dependencies.sh and rebuild.";
    return result;
#endif
}

+ (BOOL)generateSelfSignedIdentityAtP12Path:(NSString *)p12Path
                                    password:(NSString *)password
                                  commonName:(NSString *)commonName
                              validityInDays:(NSInteger)validityInDays
                                       error:(NSString **)error {
#if SWIFTIPA_HAS_ZSIGN
    EVP_PKEY *pkey = EVP_RSA_gen(2048);
    if (!pkey) {
        if (error) *error = @"Could not generate an RSA key pair.";
        return NO;
    }

    X509 *x509 = X509_new();
    ASN1_INTEGER_set(X509_get_serialNumber(x509), (long)arc4random());
    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 60L * 60L * 24L * (long)validityInDays);
    X509_set_pubkey(x509, pkey);

    X509_NAME *name = X509_get_subject_name(x509);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (const unsigned char *)[commonName UTF8String], -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "O", MBSTRING_ASC, (const unsigned char *)"SwiftIPA", -1, -1, 0);
    X509_set_issuer_name(x509, name);

    X509V3_CTX ctx;
    X509V3_set_ctx_nodb(&ctx);
    X509V3_set_ctx(&ctx, x509, x509, NULL, NULL, 0);
    X509_EXTENSION *basicConstraints = X509V3_EXT_conf_nid(NULL, &ctx, NID_basic_constraints, (char *)"critical,CA:TRUE");
    if (basicConstraints) {
        X509_add_ext(x509, basicConstraints, -1);
        X509_EXTENSION_free(basicConstraints);
    }
    X509_EXTENSION *keyUsage = X509V3_EXT_conf_nid(NULL, &ctx, NID_key_usage, (char *)"critical,digitalSignature,keyEncipherment,keyCertSign");
    if (keyUsage) {
        X509_add_ext(x509, keyUsage, -1);
        X509_EXTENSION_free(keyUsage);
    }

    if (!X509_sign(x509, pkey, EVP_sha256())) {
        if (error) *error = @"Could not sign the local server certificate.";
        X509_free(x509);
        EVP_PKEY_free(pkey);
        return NO;
    }

    PKCS12 *p12 = PKCS12_create(
        [password UTF8String],
        [commonName UTF8String],
        pkey,
        x509,
        NULL, 0, 0, 0, 0, 0
    );

    BOOL success = NO;
    if (p12) {
        FILE *file = fopen([p12Path UTF8String], "wb");
        if (file) {
            success = i2d_PKCS12_fp(file, p12) == 1;
            fclose(file);
        }
        PKCS12_free(p12);
    }

    X509_free(x509);
    EVP_PKEY_free(pkey);

    if (!success && error) {
        *error = @"Could not write the local server identity to disk.";
    }
    return success;
#else
    if (error) *error = @"The zsign engine is not vendored in this build.";
    return NO;
#endif
}

+ (NSDate *)notBeforeDateForCertificateData:(NSData *)certificateData {
    return [self dateFromCertificateData:certificateData notAfter:NO];
}

+ (NSDate *)notAfterDateForCertificateData:(NSData *)certificateData {
    return [self dateFromCertificateData:certificateData notAfter:YES];
}

+ (NSDate *)dateFromCertificateData:(NSData *)certificateData notAfter:(BOOL)wantsNotAfter {
#if SWIFTIPA_HAS_ZSIGN
    const unsigned char *bytes = static_cast<const unsigned char *>(certificateData.bytes);
    X509 *cert = d2i_X509(NULL, &bytes, (long)certificateData.length);
    if (!cert) {
        return nil;
    }

    const ASN1_TIME *asn1Time = wantsNotAfter ? X509_get0_notAfter(cert) : X509_get0_notBefore(cert);
    if (!asn1Time) {
        X509_free(cert);
        return nil;
    }

    struct tm timeComponents;
    memset(&timeComponents, 0, sizeof(timeComponents));
    if (!ASN1_TIME_to_tm(asn1Time, &timeComponents)) {
        X509_free(cert);
        return nil;
    }
    X509_free(cert);

    time_t seconds = timegm(&timeComponents);
    if (seconds == (time_t)-1) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)seconds];
#else
    (void)certificateData;
    (void)wantsNotAfter;
    return nil;
#endif
}

+ (NSData *)cmsContentFromData:(NSData *)data {
#if SWIFTIPA_HAS_ZSIGN
    std::string input(static_cast<const char *>(data.bytes), data.length);
    std::string output;
    if (!ZSignAsset::GetCMSContent(input, output)) {
        return nil;
    }
    return [NSData dataWithBytes:output.data() length:output.size()];
#else
    (void)data;
    return nil;
#endif
}

@end
