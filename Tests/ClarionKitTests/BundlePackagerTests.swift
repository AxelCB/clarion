import ClarionKit
import Testing

@Test
func bundlePackagerCommandDefaultsCanBeParsed() {
    #expect(BundlePackager.Command(rawValue: "build") == .build)
    #expect(BundlePackager.Command(rawValue: "bundle") == .bundle)
    #expect(BundlePackager.Command(rawValue: "sign") == .sign)
    #expect(BundlePackager.Command(rawValue: "install") == .install)
    #expect(BundlePackager.Command(rawValue: "all") == .all)
    #expect(BundlePackager.Command(rawValue: "clean") == .clean)
}
