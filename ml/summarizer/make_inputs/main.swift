// Builds the summary model's training inputs with the app's own SpecComparison code:
// every pair of products in the same category, plus copies with a spec or two removed so the
// model also copes with products that list fewer specs.
import Foundation

struct Spec: Codable { let label: String; let value: String }
struct ProductRecord: Codable { let name: String; let category: String; let specs: [Spec] }
struct Example: Codable {
    let category: String
    let first: String
    let second: String
    let input: String
    let facts: [SpecComparison.Fact]
    let variant: String
}

/// Small deterministic generator so the dataset is identical on every run.
struct SplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

let arguments = CommandLine.arguments
let products = try JSONDecoder().decode([ProductRecord].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
var random = SplitMix(state: 2026)
var examples: [Example] = []

func add(_ a: ProductRecord, _ b: ProductRecord, specsA: [Spec], specsB: [Spec], variant: String,
         nameA: String? = nil, nameB: String? = nil) {
    let (first, second) = (nameA ?? a.name, nameB ?? b.name)
    let facts = SpecComparison.facts(first: specsA.map { ($0.label, $0.value) }, second: specsB.map { ($0.label, $0.value) })
    let input = SpecComparison.modelInput(category: a.category, firstName: first, secondName: second, facts: facts)
    examples.append(Example(category: a.category, first: first, second: second, input: input, facts: facts, variant: variant))
}

/// "Galaxy A36 5G 8GB/256GB" → "Galaxy A36 5G": teaches the model to copy names that don't end in a storage size,
/// like the older devices in Upgrade analysis ("iPhone 13").
func shortName(_ name: String) -> String {
    name.replacingOccurrences(of: #"\s+\d+GB(/\d+(GB|TB))?$|\s+\d+TB$"#, with: "", options: .regularExpression)
}

func dropping(_ specs: [Spec]) -> [Spec] {
    guard specs.count > 3 else { return specs }
    var kept = specs
    for _ in 0..<(1 + random.below(2)) { kept.remove(at: random.below(kept.count)) }
    return kept
}

// Optional third argument: older devices users may own (Upgrade analysis). Each is paired with every
// catalogue product in its category, owned device first, as the app does.
if arguments.count > 3 {
    let owned = try JSONDecoder().decode([ProductRecord].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[3])))
    for device in owned {
        for product in products where product.category == device.category {
            add(device, product, specsA: device.specs, specsB: product.specs, variant: "upgrade")
            add(device, product, specsA: dropping(device.specs), specsB: dropping(product.specs), variant: "upgrade-dropped")
        }
    }
}

for category in ["smartphones", "laptops", "headphones"] {
    let group = products.filter { $0.category == category }
    // Laptops and headphones have few products, so they get both orders and more dropped-spec copies.
    let small = group.count < 40
    for i in group.indices {
        for j in group.indices where i != j && (small || i < j) {
            let (a, b) = small || random.below(2) == 0 ? (group[i], group[j]) : (group[j], group[i])
            add(a, b, specsA: a.specs, specsB: b.specs, variant: "full")
            if random.below(6) == 0, shortName(a.name) != shortName(b.name) {
                add(a, b, specsA: a.specs, specsB: b.specs, variant: "short-names", nameA: shortName(a.name), nameB: shortName(b.name))
            }
            if small || random.below(4) == 0 {
                add(a, b, specsA: dropping(a.specs), specsB: dropping(b.specs), variant: "dropped")
            }
        }
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let lines = try examples.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
try (lines.joined(separator: "\n") + "\n").write(toFile: arguments[2], atomically: true, encoding: .utf8)
print("wrote \(examples.count) examples to \(arguments[2])")
