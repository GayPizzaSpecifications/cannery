//
//  SerialViewController.swift
//  macOS
//
//  Created by Kenneth Endfinger on 4/16/22.
//

import Cocoa
import Foundation
import SwiftTerm
import SwiftUI
import Virtualization

class ConsoleViewController: NSViewController, TerminalViewDelegate {
    private lazy var terminalView: TerminalView = {
        let terminalView = TerminalView()
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.terminalDelegate = self
        return terminalView
    }()

    private var readPipe: Pipe?
    private var writePipe: Pipe?

    override func loadView() {
        view = NSView()
    }

    deinit {
        readPipe?.fileHandleForReading.readabilityHandler = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: view.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func clearConsoleView() {
        terminalView.getTerminal().softReset()
    }

    func configure(with readPipe: Pipe, writePipe: Pipe) {
        self.readPipe = readPipe
        self.writePipe = writePipe

        readPipe.fileHandleForReading.readabilityHandler = { [weak self] pipe in
            let data = pipe.availableData
            if let strongSelf = self {
                DispatchQueue.main.sync {
                    strongSelf.terminalView.feed(byteArray: [UInt8](data)[...])
                }
            }
        }
    }

    func send(source _: TerminalView, data: ArraySlice<UInt8>) {
        writePipe?.fileHandleForWriting.write(Data(data))
    }

    func sizeChanged(source _: TerminalView, newCols _: Int, newRows _: Int) {}
    func setTerminalTitle(source _: TerminalView, title _: String) {}
    func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}
    func scrolled(source _: TerminalView, position _: Double) {}
}
