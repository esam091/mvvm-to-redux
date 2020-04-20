//
//  CityViewController.swift
//  OpenShopRedux
//
//  Created by Samuel Edwin on 09/01/20.
//  Copyright © 2020 Samuel Edwin. All rights reserved.
//

import UIKit
import RxRelay
import RxCocoa

class CityViewController: UIViewController {

    
    @IBOutlet var button1: UIButton!
    @IBOutlet var button2: UIButton!
    @IBOutlet var button3: UIButton!
    @IBOutlet var button4: UIButton!
    
    private let _selectedCity2 = PublishRelay<City>()
    private let _dismiss = PublishRelay<Void>()
    
    @IBOutlet var closeButton: UIButton!
    
    
    var dismissed: Driver<Void> {
        return _dismiss.asDriver(onErrorDriveWith: .empty())
    }
    
    var selectedCity2: Driver<City> {
        return _selectedCity2.asDriver(onErrorDriveWith: .empty())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Signal.merge(
            button1.rx.tap.asSignal().map { City(id: 1, name: self.button1.title(for: .normal)!) },
            button2.rx.tap.asSignal().map { City(id: 2, name: self.button2.title(for: .normal)!) },
            button3.rx.tap.asSignal().map { City(id: 3, name: self.button3.title(for: .normal)!) },
            button4.rx.tap.asSignal().map { City(id: 4, name: self.button4.title(for: .normal)!) }
        )
        .do(onNext: { _ in
            self.dismiss(animated: true, completion: nil)
        })
        .emit(to: _selectedCity2)
        .disposed(by: rx.disposeBag)
        
        
        closeButton.rx.tap.asSignal().do(onNext: { _ in
            self.dismiss(animated: true, completion: nil)
            }).emit(to: _dismiss)
            .disposed(by: rx.disposeBag)
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
