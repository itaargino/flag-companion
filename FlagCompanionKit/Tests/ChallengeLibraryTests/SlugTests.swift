import ChallengeLibrary
import Testing

@Test(arguments: [
    ("picoCTF 2026", "picoctf-2026"),
    ("enc", "enc"),
    ("Ação e Reação", "acao-e-reacao"),
    ("Crypto: enc!", "crypto-enc"),
    ("my__first   challenge", "my-first-challenge"),
    ("  --hidden--  ", "hidden"),
    ("binary_exploitation.v2", "binary-exploitation-v2"),
])
func slugIsBuiltFromName(name: String, expected: String) throws {
    let slug = try Slug(name)
    #expect(slug.value == expected)
}

@Test(arguments: ["!!!", "", "密码学"])
func nameWithoutLatinLettersOrDigitsIsRejected(name: String) {
    #expect(throws: SlugError.self) {
        _ = try Slug(name)
    }
}
