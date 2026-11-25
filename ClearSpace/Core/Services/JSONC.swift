import Foundation

/// Reads "JSON with comments", the format VS Code uses for `tasks.json`, `settings.json`
/// and `.code-workspace` files. Strips a byte order mark, `//` and `/* */` comments and
/// trailing commas, then hands the rest to `JSONSerialization`.
enum JSONC {
    static func object(from data: Data) -> [String: Any]? {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        let clean = sanitize(text)
        guard let json = clean.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: json, options: [.fragmentsAllowed])) as? [String: Any]
    }

    /// Returns `text` as plain JSON. Comment markers inside strings are kept.
    static func sanitize(_ text: String) -> String {
        let chars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(chars.count)

        var index = 0
        var inString = false
        while index < chars.count {
            let c = chars[index]
            let next: Unicode.Scalar? = index + 1 < chars.count ? chars[index + 1] : nil

            if inString {
                out.append(c)
                if c == "\\", let next {
                    out.append(next)
                    index += 2
                    continue
                }
                if c == "\"" { inString = false }
                index += 1
                continue
            }

            switch c {
            case "\u{FEFF}":
                index += 1
            case "\"":
                inString = true
                out.append(c)
                index += 1
            case "/" where next == "/":
                while index < chars.count, chars[index] != "\n" { index += 1 }
            case "/" where next == "*":
                index += 2
                while index + 1 < chars.count, !(chars[index] == "*" && chars[index + 1] == "/") { index += 1 }
                index += 2
            case ",":
                // Drop the comma when only whitespace or comments lead to a closing bracket.
                var look = index + 1
                while look < chars.count {
                    let l = chars[look]
                    if l == " " || l == "\t" || l == "\n" || l == "\r" {
                        look += 1
                    } else if l == "/", look + 1 < chars.count, chars[look + 1] == "/" {
                        while look < chars.count, chars[look] != "\n" { look += 1 }
                    } else if l == "/", look + 1 < chars.count, chars[look + 1] == "*" {
                        look += 2
                        while look + 1 < chars.count, !(chars[look] == "*" && chars[look + 1] == "/") { look += 1 }
                        look += 2
                    } else {
                        break
                    }
                }
                if look < chars.count, chars[look] == "}" || chars[look] == "]" {
                    index += 1
                } else {
                    out.append(c)
                    index += 1
                }
            default:
                out.append(c)
                index += 1
            }
        }
        return String(out)
    }
}
