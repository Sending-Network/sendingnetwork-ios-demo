//
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import XCTest

@testable import SendingnNetworkSwiftUI

class TimelinePollViewModelTests: XCTestCase {
    var viewModel: TimelinePollViewModel!
    var context: TimelinePollViewModelType.Context!
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        let answerOptions = [TimelinePollAnswerOption(id: "1", text: "1", count: 1, winner: false, selected: false),
                             TimelinePollAnswerOption(id: "2", text: "2", count: 1, winner: false, selected: false),
                             TimelinePollAnswerOption(id: "3", text: "3", count: 1, winner: false, selected: false)]
        
        let timelinePoll = TimelinePollDetails(id: "poll-id",
                                               question: "Question",
                                               answerOptions: answerOptions,
                                               closed: false,
                                               startDate: .init(),
                                               totalAnswerCount: 3,
                                               type: .disclosed,
                                               eventType: .started,
                                               maxAllowedSelections: 1,
                                               hasBeenEdited: false,
                                               hasDecryptionError: false)
        
        viewModel = TimelinePollViewModel(timelinePollDetailsState: .loaded(timelinePoll))
        context = viewModel.context
    }
    
    func testInitialState() {
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions.count, 3)
        XCTAssertEqual(context.viewState.pollState.poll?.closed, false)
        XCTAssertEqual(context.viewState.pollState.poll?.type, .disclosed)
    }
    
    func testSingleSelectionOnMax1Allowed() {
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }
    
    func testSingleReselectionOnMax1Allowed() {
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }
    
    func testMultipleSelectionOnMax1Allowed() {
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, true)
    }
    
    func testMultipleReselectionOnMax1Allowed() {
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, true)
    }

    func testClosedSelection() {
        guard case var .loaded(poll) = context.viewState.pollState else {
            return XCTFail()
        }
        poll.closed = true
        viewModel.updateWithPollDetailsState(.loaded(poll))

        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }

    func testSingleSelectionOnMax2Allowed() {
        guard case var .loaded(poll) = context.viewState.pollState else {
            return XCTFail()
        }
        poll.maxAllowedSelections = 2
        viewModel.updateWithPollDetailsState(.loaded(poll))
        
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }
    
    func testSingleReselectionOnMax2Allowed() {
        guard case var .loaded(poll) = context.viewState.pollState else {
            return XCTFail()
        }
        poll.maxAllowedSelections = 2
        viewModel.updateWithPollDetailsState(.loaded(poll))
        
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }
    
    func testMultipleSelectionOnMax2Allowed() {
        guard case var .loaded(poll) = context.viewState.pollState else {
            return XCTFail()
        }
        poll.maxAllowedSelections = 2
        viewModel.updateWithPollDetailsState(.loaded(poll))

        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        context.send(viewAction: .selectAnswerOptionWithIdentifier("2"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, true)
        
        context.send(viewAction: .selectAnswerOptionWithIdentifier("1"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, true)
        
        context.send(viewAction: .selectAnswerOptionWithIdentifier("2"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, true)
        
        context.send(viewAction: .selectAnswerOptionWithIdentifier("3"))
        
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[0].selected, false)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[1].selected, true)
        XCTAssertEqual(context.viewState.pollState.poll?.answerOptions[2].selected, false)
    }
}

private extension TimelinePollDetailsState {
    var poll: TimelinePollDetails? {
        switch self {
        case .loaded(let poll):
            return poll
        default:
            return nil
        }
    }
}
