//
//  WrapLineView.swift
//  GitReads
//
//  Created by Zhou Jiahao on 11/3/22.
//

import SwiftUI

struct WrapLineView: View {
    // will be in viewmodel logic
    @StateObject var viewModel: ScreenViewModel
    let lineNum: Int
    let screenWidth = UIScreen.main.bounds.width
    let padding: CGFloat = 100
    var indetationLevel = 4
    let line: Line
    var group = [[String]]()
    @Binding var fontSize: Int

    init(viewModel: ScreenViewModel, lineNum: Int, line: Line, fontSize: Binding<Int>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.lineNum = lineNum
        _fontSize = fontSize
        self.line = line
        self.group = createGroup(line)
    }

    private func createGroup(_ line: Line) -> [[String]] {
        var group = [[String]]()
        var subGroup = [String]()
        var width: CGFloat = padding
        var space = ""
        for _ in 0..<indetationLevel {
            space += " "
        }
        let indentation = UILabel()
        indentation.text = space

        for token in line.tokens {
            // Need a better way of doing it
            let wordWidth = CGFloat(token.value.count * $fontSize.wrappedValue / 2)

            if width + wordWidth < screenWidth {
                width += wordWidth
                subGroup.append(token.value)
            } else {
                group.append(subGroup)
                subGroup = [space, token.value]
                width = wordWidth + indentation.frame.width + padding
            }
        }
        group.append(subGroup)
        return group
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(group, id: \.self) { subGroup in
                HStack {
                    ForEach(subGroup, id: \.self) { _ in
//                        TokenView(
//                            viewModel: viewModel,
//                            token: Token(type: .keyword, value: word),
//                            fontSize: $fontSize
//                        )
                    }
                }
            }
        }
    }
}

struct WrapLineView_Previews: PreviewProvider {
    @State static var fontSize = 25
    static var previews: some View {
        WrapLineView(
            viewModel: ScreenViewModel(),
            lineNum: 0,
            line: Line(tokens: [
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST"),
                Token(type: .keyword, value: "TEST")
            ]),
            fontSize: $fontSize)
    }
}
