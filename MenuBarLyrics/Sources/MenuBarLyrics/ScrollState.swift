import Foundation

struct ScrollState {
    private(set) var tick = 0

    mutating func reset() {
        tick = 0
    }

    mutating func advance() {
        tick += 1
    }

    func visibleText(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        let characters = Array(text)
        guard characters.count > maxCharacters else { return text }

        let pause = 6
        let span = characters.count - maxCharacters
        let cycle = pause + span + pause
        let phase = tick % max(cycle, 1)

        let start: Int
        if phase < pause {
            start = 0
        } else if phase < pause + span {
            start = phase - pause
        } else {
            start = span
        }

        let end = min(start + maxCharacters, characters.count)
        return String(characters[start..<end])
    }
}
