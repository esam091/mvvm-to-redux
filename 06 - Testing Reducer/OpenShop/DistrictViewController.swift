//
//  DistrictViewController.swift
//  OpenShopRedux
//
//  Created by Samuel Edwin on 17/01/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

class DistrictViewController: UIViewController {

    @IBOutlet var button1: UIButton!
    @IBOutlet var button2: UIButton!
    @IBOutlet var button3: UIButton!
    @IBOutlet var button4: UIButton!
    
    @IBOutlet var closeButton: UIButton!
    
    private let output = PublishSubject<District>()
    
    public var selectedDistrict: Driver<District> {
        return output.asDriver(onErrorDriveWith: .empty())
    }
    
    private let close = PublishSubject<Void>()
    
    public var closed: Driver<Void> {
        return close.asDriver(onErrorDriveWith: .empty())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Driver.merge(
            button1.rx.tap.asDriver().map { District(id: 1, name: self.button1.titleLabel!.text!) },
            button2.rx.tap.asDriver().map { District(id: 2, name: self.button2.titleLabel!.text!) },
            button3.rx.tap.asDriver().map { District(id: 3, name: self.button3.titleLabel!.text!) },
            button4.rx.tap.asDriver().map { District(id: 4, name: self.button4.titleLabel!.text!) }
        )
            .do(onNext: { _ in
                self.dismiss(animated: true, completion: nil)
            })
        
            .drive(output).disposed(by: rx.disposeBag)
        
        closeButton.rx.tap.asDriver().do(onNext: { _ in
            self.dismiss(animated: true, completion: nil)
        }).drive(close).disposed(by: rx.disposeBag)
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
