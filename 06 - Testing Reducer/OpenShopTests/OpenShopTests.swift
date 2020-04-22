//
//  OpenShopTests.swift
//  OpenShopTests
//
//  Created by Samuel Edwin on 19/04/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import XCTest
@testable import OpenShop
import RxSwift
import RxCocoa

struct Step<Value, Action> {
    let kind: Kind
    let action: Action?
    let update: (inout Value) -> Void
    let file: StaticString
    let line: UInt
    
    enum Kind {
        case send
        case receive
    }
    
    init(_ kind: Kind, action: Action?, file: StaticString = #file, line: UInt = #line, update: @escaping (inout Value) -> Void = { _ in }) {
        self.kind = kind
        self.update = update
        self.file = file
        self.line = line
        self.action = action
    }
}

func assertSteps<Value: Equatable, Action: Equatable, Environment>(
    initialValue: Value,
    reducer: @escaping (inout Value, Action, Environment) -> [Driver<Action>],
    environment: Environment,
    steps: Step<Value, Action>...,
    file: StaticString = #file,
    line: UInt = #line
) {
    var pendingEffects: [Driver<Action>] = []
    var value = initialValue
    let disposeBag = DisposeBag()
    
    steps.forEach { step in
        var expected = value
        
        switch step.kind {
        case .send:
            if !pendingEffects.isEmpty {
                XCTFail("Unprocessed effect detected before sending another action", file: step.file, line: step.line)
            }
            
            guard let action = step.action else {
                XCTAssertNotNil(step.action, "Actions cannot be nil when sending", file: step.file, line: step.line)
                break
            }
            
            let effects = reducer(&value, action, environment)
            pendingEffects.append(contentsOf: effects)
            
        case .receive:
            if pendingEffects.isEmpty {
                XCTFail("No more effect to process", file: step.file, line: step.line)
                break
            }
            
            let waiter = XCTWaiter()
            let expectation = XCTestExpectation(description: "stream completion")
            
            var receivedAction: Action?
            
            let effect = pendingEffects.removeFirst()
            effect
                .drive(onNext: { action in
                    receivedAction = action
                }, onCompleted: {
                    expectation.fulfill()
                })
                .disposed(by: disposeBag)
            
            waiter.wait(for: [expectation], timeout: 0.01)
            
            
            
            if let action = receivedAction {
                XCTAssertEqual(step.action, action, file: step.file, line: step.line)
                
                let effects = reducer(&value, action, environment)
                pendingEffects.append(contentsOf: effects)
            }
        }
        
        
        step.update(&expected)
        
        XCTAssertEqual(value, expected, file: step.file, line: step.line)
    }
    
    if !pendingEffects.isEmpty {
        XCTFail("There are still \(pendingEffects.count) unprocessed effects", file: file, line: line)
    }
}

class OpenShopTests: XCTestCase {
    
    func test_inputShowName_showDomainSuggestion() {
        var useCase = UseCase.mock
        useCase.checkShopName = { _ in
            Driver.just(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))
        }
        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopNameDidChange("my shop")) {
                $0.shopName = "my shop"
            },
            Step(.receive, action: .didValidateShopName(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))) {
                $0.selectedDomainName = "foo"
            }
        )
    }

    func test_inputShopName_showDomainSuggestionWithErrors() {
        var useCase = UseCase.mock
        
        useCase.checkShopName = { _ in
            Driver.just(ValidateShopNameResponse(suggestedDomain: "bar", shopNameErrorMessage: "error message"))
                
        }

        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopNameDidChange("my shop")) {
                $0.shopName = "my shop"
            },
            Step(.receive, action: .didValidateShopName(ValidateShopNameResponse(suggestedDomain: "bar", shopNameErrorMessage: "error message"))) {
                $0.selectedDomainName = "bar"
                $0.shopNameErrorMessage = "error message"
            }
        )
    }

    func test_inputDomainName_valid() {
        var useCase = UseCase.mock
        useCase.checkDomainName = { _ in
            .just(.success(()))
        }

        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopDomainDidChange("foo")) {
                $0.selectedDomainName = "foo"
            },
            Step(.receive, action: nil) // TODO: nil action don't need to be listed
        )
    }

    func test_inputDomainName_invalid() {
        var useCase = UseCase.mock
        useCase.checkDomainName = { _ in
            .just(.failure(SimpleErrorMessage(message: "error")))
        }
        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopDomainDidChange("domain")) {
                $0.selectedDomainName = "domain"
            },
            Step(.receive, action: .domainNameError("error")) {
                $0.domainErrorMessage = "error"
            }
        )
    }

    func test_inputCity_dismissed() {
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: UseCase.mock,
            steps:
            Step(.send, action: .cityDidDismissed) {
                $0.cityError = .dismissed
            }
        )
    }

    func test_inputCity_success() {
        let city = City(id: 1, name: "Hyrule")
        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: UseCase.mock,
            steps:
            Step(.send, action: .cityDidDismissed) {
                $0.cityError = .dismissed
            },
            Step(.send, action: .cityDidSelected(city)) {
                $0.city = city
                $0.cityError = nil
            },
            Step(.send, action: .cityDidDismissed)
            
        )
    }

    func test_inputDistrict_success() {
        let city = City(id: 2, name: "Tokyo")
        let district = District(id: 1, name: "Shibuya")

        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: UseCase.mock,
            steps:
            Step(.send, action: .cityDidSelected(city)) {
                $0.city = city
            },
            Step(.send, action: .districtDidTapped),
            Step(.receive, action: .showDistrictSelection),
            Step(.send, action: .districtDidSelected(district)) {
                $0.district = district
            }
        )
    }

    func test_inputDistrict_noCitySelected() {
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: UseCase.mock,
            steps: Step(.send, action: .districtDidTapped) {
                $0.districtError = .noCitySelected
            }
        )
    }

    func test_inputDistrict_dismissed() {
        let city = City(id: 2, name: "Tokyo")

        assertSteps(
            initialValue: State(city: city), // start the state from when the city is already selected
            reducer: reducer,
            environment: UseCase.mock,
            steps:
            Step(.send, action: .districtDidTapped),
            Step(.receive, action: .showDistrictSelection),
            Step(.send, action: .districtDidDismissed) {
                $0.districtError = .dismissed
            }
        )
    }

    func test_allFieldsValid_willSubmitToServer() {
        let useCase = UseCase.mock
        
        let city = City(id: 2, name: "Tokyo")
        let district = District(id: 1, name: "Shibuya")

        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo-domain", shopNameErrorMessage: nil))
        }


        useCase.submit = { _ in
            .just(.success(Unit()))
        }
        
        assertSteps(
            initialValue: State(),
            reducer: reducer,
            environment: useCase,
            steps:
            Step(.send, action: .shopNameDidChange("Nook Inc")) {
                $0.shopName = "Nook Inc"
            },
            Step(.receive, action: .didValidateShopName(ValidateShopNameResponse(suggestedDomain: "foo-domain", shopNameErrorMessage: nil))) {
                $0.selectedDomainName = "foo-domain"
            },
            Step(.send, action: .cityDidSelected(city)) {
                $0.city = city
            },
            Step(.send, action: .districtDidTapped),
            Step(.receive, action: .showDistrictSelection),
            Step(.send, action: .districtDidSelected(district)) {
                $0.district = district
            },
            Step(.send, action: .submitButtonDidTap),
            Step(.receive, action: .submissionResult(.success(Unit())))
            
        )
    }
}
