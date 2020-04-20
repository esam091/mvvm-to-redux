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

class TestObserver<Element>: ObserverType {
    private var events: [Event<Element>] = []
    
    func on(_ event: Event<Element>) {
        events.append(event)
    }
    
    func assertDidEmitValues(count: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(events.count, count, file: file, line: line)
    }
}

extension TestObserver where Element: Equatable {
    func assertValues(_ values: [Element], file: StaticString = #file, line: UInt = #line) {
        let storedValues = events.filter { $0.element != nil }.map { $0.element! }
        
        XCTAssertEqual(storedValues, values, file: file, line: line)
        
    }
}



class OpenShopTests: XCTestCase {
    var viewModel: ViewModel!
    var useCase: UseCase!
    
    var disposeBag = DisposeBag()
    
    let shopNameDidChange = PublishSubject<String>()
    let shopDomainDidChange = PublishSubject<String>()
    let cityDidSelected = PublishSubject<City>()
    let cityDidDismissed = PublishSubject<Void>()
    let districtDidTapped = PublishSubject<Void>()
    let districtDidSelected = PublishSubject<District>()
    let districtDidDismissed = PublishSubject<Void>()
    let submitButtonDidTap = PublishSubject<Void>()
    
    let shopNameError = TestObserver<String?>()
    let domainName = TestObserver<String>()
    let domainNameError = TestObserver<String?>()
    let selectedCity = TestObserver<City>()
    let citySelectionError = TestObserver<CitySelectionError?>()
    let selectedDistrict = TestObserver<District>()
    let districtSelectionError = TestObserver<DistrictSelectionError?>()
    let showDistrictSelection = TestObserver<Void>()
    let submissionResult = TestObserver<Result<Void, SimpleErrorMessage>>()
    
    override func tearDown() {
        disposeBag = DisposeBag()
    }
    
    override func setUp() {
        let input = ViewModel.Input(
            shopNameDidChange: shopNameDidChange.asDriver(onErrorDriveWith: .empty()),
            shopDomainDidChange: shopDomainDidChange.asDriver(onErrorDriveWith: .empty()),
            cityDidSelected: cityDidSelected.asDriver(onErrorDriveWith: .empty()),
            cityDidDismissed: cityDidDismissed.asDriver(onErrorDriveWith: .empty()),
            districtDidTapped: districtDidTapped.asDriver(onErrorDriveWith: .empty()),
            districtDidSelected: districtDidSelected.asDriver(onErrorDriveWith: .empty()),
            districtDidDismissed: districtDidDismissed.asDriver(onErrorDriveWith: .empty()),
            submitButtonDidTap: submitButtonDidTap.asDriver(onErrorDriveWith: .empty())
        )
        
        useCase = UseCase.mock
        viewModel = ViewModel(useCase: useCase)
        
        let output = viewModel.transform(input)
        output.shopNameError.drive(shopNameError).disposed(by: disposeBag)
        output.domainName.drive(domainName).disposed(by: disposeBag)
        output.domainNameError.drive(domainNameError).disposed(by: disposeBag)
        output.selectedCity.drive(selectedCity).disposed(by: disposeBag)
        output.citySelectionError.drive(citySelectionError).disposed(by: disposeBag)
        output.selectedDistrict.drive(selectedDistrict).disposed(by: disposeBag)
        output.districtSelectioonError.drive(districtSelectionError).disposed(by: disposeBag)
        output.showDistrictSelection.drive(showDistrictSelection).disposed(by: disposeBag)
        output.submissionResult.drive(submissionResult).disposed(by: disposeBag)
    }

    func test_inputShowName_showDomainSuggestion() {
        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo", shopNameErrorMessage: nil))
        }
        
        shopNameDidChange.onNext("something")
        
        shopNameError.assertValues([nil])
        domainName.assertValues(["foo"])
    }
    
    func test_inputShopName_showDomainSuggestionWithErrors() {
        let called = expectation(description: "use case called")
        
        useCase.checkShopName = { _ in
            Driver.just(ValidateShopNameResponse(suggestedDomain: "bar", shopNameErrorMessage: "error message"))
                .delay(.nanoseconds(1))
                .do(onNext: { _ in called.fulfill() })
        }
        
        shopNameDidChange.onNext("another thing")
        
        wait(for: [called], timeout: 0.001)
        
        shopNameError.assertValues([nil, "error message"])
        domainName.assertValues(["bar"])
    }
    
    func test_inputDomainName_valid() {
        useCase.checkDomainName = { _ in
            .just(.success(()))
        }
        
        shopDomainDidChange.onNext("foo")
        
        domainNameError.assertValues([nil, nil])
    }
    
    func test_inputDomainName_invalid() {
        useCase.checkDomainName = { _ in
            .just(.failure(SimpleErrorMessage(message: "error")))
        }
        
        shopDomainDidChange.onNext("foo")
        
        domainNameError.assertValues([nil, "error"])
    }
    
    func test_inputCity_dismissed() {
        cityDidDismissed.onNext(())
        
        citySelectionError.assertValues([.dismissed])
    }
    
    func test_inputCity_success() {
        let city = City(id: 1, name: "Hyrule")
        cityDidSelected.onNext(city)
        
        selectedCity.assertValues([city])
        
        cityDidDismissed.onNext(())
        
        selectedCity.assertValues([city])
    }
    
    func test_inputDistrict_success() {
        let city = City(id: 2, name: "Tokyo")
        let district = District(id: 1, name: "Shibuya")
        
        cityDidSelected.onNext(city)
        
        districtDidTapped.onNext(())
        
        showDistrictSelection.assertDidEmitValues(count: 1)
        
        districtDidSelected.onNext(district)
        
        selectedDistrict.assertValues([district])
    }
    
    func test_inputDistrict_noCitySelected() {
        districtDidTapped.onNext(())
        
        districtSelectionError.assertValues([.noCitySelected])
    }
    
    func test_inputDistrict_dismissed() {
        let city = City(id: 2, name: "Tokyo")
        
        cityDidSelected.onNext(city)
        
        districtDidTapped.onNext(())
        
        showDistrictSelection.assertDidEmitValues(count: 1)
        
        districtDidDismissed.onNext(())
        
        districtSelectionError.assertValues([nil, .dismissed])
    }
    
    func test_allFieldsValid_willSubmitToServer() {
        let city = City(id: 2, name: "Tokyo")
        let district = District(id: 1, name: "Shibuya")
        
        useCase.checkShopName = { _ in
            .just(ValidateShopNameResponse(suggestedDomain: "foo-domain", shopNameErrorMessage: nil))
        }
        
        useCase.submit = { _ in
            .just(.success(()))
        }
        
        
        shopNameDidChange.onNext("foo-shop")
        
        cityDidSelected.onNext(city)
        
        districtDidTapped.onNext(())
        
        districtDidSelected.onNext(district)
        
        submitButtonDidTap.onNext(())
        
        submissionResult.assertDidEmitValues(count: 1)
    }
}
