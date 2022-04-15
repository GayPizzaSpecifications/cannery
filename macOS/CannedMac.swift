//
//  CannedMac.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/22/22.
//

import Combine
import Foundation
import SwiftUI
import Virtualization

class CannedMac: ObservableObject {
    static let defaultVirtualMachineName = "macOS"

    @Published
    var state: CannedMacState = .unknown

    @Published
    var downloadCurrentProgress: Double = 0.0

    @Published
    var installerCurrentProgress: Double = 0.0

    @Published
    var error: Error?

    @Published
    var vm: VZVirtualMachine?

    @Published
    var currentVmState: VZVirtualMachine.State = .stopped

    @Published
    var isResetRequested: Bool = false

    @Published
    var isSwitchMachine: Bool = false

    var downloadProgressObserver: NSKeyValueObservation?
    var installProgressObserver: NSKeyValueObservation?
    var currentStateObserver: NSKeyValueObservation?

    #if CANNED_MAC_USE_PRIVATE_APIS
    var vmVncServer: _VZVNCServer?
    #endif

    var virtualMachineName: String

    init(virtualMachineName: String = defaultVirtualMachineName) {
        self.virtualMachineName = virtualMachineName
        do {
            try migrateOldDirectoryIfNecessary()
        } catch {
            fatalError("Failed to migrate old virtual machine format: \(error.localizedDescription)")
        }
    }

    func swapMachineName(name: String) {
        isSwitchMachine = false
        if virtualMachineName == name {
            return
        }
        UserDefaults.standard.set(name, forKey: "virtualMachineName")
        vm = nil
        virtualMachineName = name
    }

    func createVmConfiguration(_ options: VirtualMachineOptions, displaySize: CGSize?) async throws -> (VZVirtualMachineConfiguration, VZMacOSRestoreImage?) {
        let existingHardwareModel = try loadMacHardwareModel()

        let model: VZMacHardwareModel
        let macRestoreImage: VZMacOSRestoreImage?
        if existingHardwareModel == nil {
            let image = try await downloadLatestSupportImage()

            guard let mostFeaturefulSupportedConfiguration = image.mostFeaturefulSupportedConfiguration else {
                throw UserError(.RestoreImageBad, "Restore image did not have a supported configuration.")
            }

            model = mostFeaturefulSupportedConfiguration.hardwareModel
            try saveMacHardwareModel(mostFeaturefulSupportedConfiguration.hardwareModel)
            macRestoreImage = image
        } else {
            model = existingHardwareModel!
            macRestoreImage = nil
        }

        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = computeCpuCount()
        configuration.memorySize = computeMemorySize(options.memoryInGigabytes)

        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = try loadOrCreateMachineIdentifier()
        platform.auxiliaryStorage = try loadOrCreateAuxilaryStorage(model)
        platform.hardwareModel = model
        configuration.platform = platform
        configuration.bootLoader = VZMacOSBootLoader()

        let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        soundDeviceConfiguration.streams = [inputStream, outputStream]
        configuration.audioDevices.append(soundDeviceConfiguration)

        let diskImageAttachment = try getOrCreateDiskImage()
        let storage = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
        configuration.storageDevices.append(storage)

        let network = VZVirtioNetworkDeviceConfiguration()
        network.macAddress = try loadOrCreateMacAddress(network.macAddress)
        network.attachment = VZNATNetworkDeviceAttachment()
        configuration.networkDevices.append(network)

        let keyboard: VZKeyboardConfiguration
        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.macInputMode {
            keyboard = VZPrivateUtilities.createMacKeyboardConfiguration()
        } else {
            keyboard = VZUSBKeyboardConfiguration()
        }
        #else
        keyboard = VZUSBKeyboardConfiguration()
        #endif
        configuration.keyboards.append(keyboard)

        let pointingDevice: VZPointingDeviceConfiguration
        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.macInputMode {
            pointingDevice = VZPrivateUtilities.createMacTrackpadConfiguration()
        } else {
            pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
        }
        #else
        pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
        #endif
        configuration.pointingDevices.append(pointingDevice)

        let memoryBalloon = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
        configuration.memoryBalloonDevices.append(memoryBalloon)

        let gpu = VZMacGraphicsDeviceConfiguration()

        let resolution = options.displayResolution

        let widthInPixels: Int
        let heightInPixels: Int
        let pixelsPerInch: Int
        if let displaySize = displaySize {
            widthInPixels = Int(displaySize.width)
            heightInPixels = Int(displaySize.height)
            pixelsPerInch = 80
        } else {
            widthInPixels = resolution.width
            heightInPixels = resolution.height
            pixelsPerInch = 80
        }

        let display = VZMacGraphicsDisplayConfiguration(
            widthInPixels: widthInPixels,
            heightInPixels: heightInPixels,
            pixelsPerInch: pixelsPerInch
        )
        gpu.displays.append(display)
        configuration.graphicsDevices.append(gpu)

        let entropy = VZVirtioEntropyDeviceConfiguration()
        configuration.entropyDevices.append(entropy)

        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.gdbDebugStub {
            let stub = VZPrivateUtilities.createGdbDebugStub(1)
            configuration.setGdbDebugStub(stub)
        }
        #endif

        if options.serialPortOutputEnabled {
            let virtualMachineDirectory = try getVirtualMachineDirectory()
            let serialOutputUrl = virtualMachineDirectory.appendingPathComponent("serial0.out")
            if FileManager.default.fileExists(at: serialOutputUrl) {
                try FileManager.default.removeItem(at: serialOutputUrl)
            }
            FileManager.default.createFile(atPath: serialOutputUrl.path, contents: nil)
            let handle = try FileHandle(forWritingTo: serialOutputUrl)
            let serialPort = options.serialPortOutputType.createSerialPortConfiguration()
            serialPort.attachment = VZFileHandleSerialPortAttachment(
                fileHandleForReading: nil, fileHandleForWriting: handle
            )
            configuration.serialPorts.append(serialPort)
        }

        try configuration.validate()
        return (configuration, macRestoreImage)
    }

    @MainActor
    func bootVirtualMachine(_ options: VirtualMachineOptions, currentViewSize: CGSize) async throws {
        #if CANNED_MAC_USE_PRIVATE_APIS
        if vmVncServer != nil {
            vmVncServer!.stop()
            vmVncServer = nil
        }
        #endif

        let currentViewSizeAutomatic = options.displayResolution.isAutomatic ? currentViewSize : nil
        let (configuration, macRestoreImage) = try await createVmConfiguration(options, displaySize: currentViewSizeAutomatic)
        let vm = VZVirtualMachine(configuration: configuration, queue: DispatchQueue.main)

        if let macRestoreImage = macRestoreImage {
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: macRestoreImage.url)
            installProgressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
                DispatchQueue.main.async {
                    if let value = change.newValue {
                        self.installerCurrentProgress = value
                    }
                }
            }
            DispatchQueue.main.async {
                self.state = .installingMacOS
            }
            try await installer.install()
            while vm.state != .stopped {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        DispatchQueue.main.async {
            self.state = .bootVirtualMachine
            self.vm = vm
        }

        currentStateObserver = vm.observe(\.state, options: [.initial, .new]) { machine, _ in
            DispatchQueue.main.async {
                self.currentVmState = machine.state
            }
        }

        #if CANNED_MAC_USE_PRIVATE_APIS
        if options.vncServerEnabled {
            let vncServerPassword = options.vncServerAuthenticationEnabled ? options.vncServerPassword : nil
            let server = VZPrivateUtilities.createVncServer(port: options.vncServerPort, queue: DispatchQueue.main, password: vncServerPassword)
            server.virtualMachine = vm
            server.start()
            vmVncServer = server
        } else {
            vmVncServer = nil
        }

        let startOptions = VZExtendedVirtualMachineStartOptions()
        startOptions.bootMacOSRecovery = options.bootToRecovery
        try await vm.extendedStart(with: startOptions)
        #else
        try await vm.start()
        #endif
    }

    @MainActor
    func deleteVirtualMachine() async throws {
        if let vm = vm {
            if vm.state != .stopped {
                try await vm.stop()
            }
        }

        try deleteVirtualMachineDirectory()
        isResetRequested = false
    }

    func loadMacHardwareModel() throws -> VZMacHardwareModel? {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let hardwareModelUrl = virtualMachineDirectory.appendingPathComponent("machw.bin")

        if FileManager.default.fileExists(at: hardwareModelUrl) {
            let data = try Data(contentsOf: hardwareModelUrl)
            return VZMacHardwareModel(dataRepresentation: data)
        }
        return nil
    }

    func saveMacHardwareModel(_ model: VZMacHardwareModel) throws {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let hardwareModelUrl = virtualMachineDirectory.appendingPathComponent("machw.bin")
        try model.dataRepresentation.write(to: hardwareModelUrl)
    }

    func downloadLatestSupportImage() async throws -> VZMacOSRestoreImage {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let restoreIpswFileUrl = virtualMachineDirectory.appendingPathComponent("restore.ipsw")
        if FileManager.default.fileExists(at: restoreIpswFileUrl) {
            return try await VZMacOSRestoreImage.image(from: restoreIpswFileUrl)
        }

        state = .downloadInstaller

        let image = try await VZMacOSRestoreImage.latestSupported
        let future: Future<URL?, Error> = Future { promise in
            let task = URLSession.shared.downloadTask(with: image.url) { url, _, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                promise(.success(url))
            }

            self.downloadProgressObserver = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { _, change in
                if let value = change.newValue {
                    DispatchQueue.main.async {
                        self.downloadCurrentProgress = value
                    }
                }
            }

            DispatchQueue.main.async {
                self.state = .downloadInstaller
            }
            task.resume()
        }

        let temporaryFileUrl = try await future.value

        guard let temporaryFileUrl = temporaryFileUrl else {
            throw UserError(.DownloadFailed, "Download of installer failed.")
        }

        try FileManager.default.moveItem(at: temporaryFileUrl, to: restoreIpswFileUrl)

        return try await VZMacOSRestoreImage.image(from: restoreIpswFileUrl)
    }

    func loadOrCreateAuxilaryStorage(_ model: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let auxilaryStorageUrl = virtualMachineDirectory.appendingPathComponent("macaux.bin")

        if FileManager.default.fileExists(at: auxilaryStorageUrl) {
            return VZMacAuxiliaryStorage(contentsOf: auxilaryStorageUrl)
        } else {
            return try VZMacAuxiliaryStorage(creatingStorageAt: auxilaryStorageUrl, hardwareModel: model)
        }
    }

    func loadOrCreateMachineIdentifier() throws -> VZMacMachineIdentifier {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let macIdentifierUrl = virtualMachineDirectory.appendingPathComponent("macid.bin")

        if FileManager.default.fileExists(at: macIdentifierUrl) {
            let data = try Data(contentsOf: macIdentifierUrl)
            return VZMacMachineIdentifier(dataRepresentation: data)!
        } else {
            let identifier = VZMacMachineIdentifier()
            let data = identifier.dataRepresentation
            try data.write(to: macIdentifierUrl)
            return identifier
        }
    }

    func loadOrCreateMacAddress(_ randomAddress: VZMACAddress) throws -> VZMACAddress {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let macAddressUrl = virtualMachineDirectory.appendingPathComponent("macaddress.bin")

        if FileManager.default.fileExists(at: macAddressUrl) {
            let data = try Data(contentsOf: macAddressUrl)
            let string = String(data: data, encoding: .utf8)!
            return VZMACAddress(string: string)!
        } else {
            let string = randomAddress.string
            let data = string.data(using: .utf8)!
            try data.write(to: macAddressUrl)
            return randomAddress
        }
    }

    func getOrCreateDiskImage() throws -> VZDiskImageStorageDeviceAttachment {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        let diskImageUrl = virtualMachineDirectory.appendingPathComponent("disk.img")

        if FileManager.default.fileExists(at: diskImageUrl) {
            return try VZDiskImageStorageDeviceAttachment(url: diskImageUrl, readOnly: false)
        } else {
            var diskSpaceToUse = Int64(128 * 1024 * 1024 * 1024)
            if try FileUtilities.diskSpaceAvailable() < diskSpaceToUse {
                diskSpaceToUse = 64 * 1024 * 1024 * 1024
            }
            try FileUtilities.createSparseImage(diskImageUrl, size: diskSpaceToUse)
            return try VZDiskImageStorageDeviceAttachment(url: diskImageUrl, readOnly: false)
        }
    }

    func computeMemorySize(_ memory: Int) -> UInt64 {
        var memorySize = (UInt64(memory) * 1024 * 1024 * 1024) as UInt64
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

        return memorySize
    }

    func computeCpuCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }

    func deleteVirtualMachineDirectory() throws {
        let virtualMachineDirectory = try getVirtualMachineDirectory()
        try FileManager.default.trashItem(at: virtualMachineDirectory, resultingItemURL: nil)
        _ = try getVirtualMachineDirectory()
    }

    func getVirtualMachineDirectory(createIfNotExists: Bool = true) throws -> URL {
        let applicationSupportDirectoryUrl = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineDirectory = applicationSupportDirectoryUrl.appendingPathComponent(virtualMachineName)
        if createIfNotExists {
            try FileManager.default.createDirectory(at: virtualMachineDirectory, withIntermediateDirectories: true)
        }
        return virtualMachineDirectory
    }

    func migrateOldDirectoryIfNecessary() throws {
        if virtualMachineName != CannedMac.defaultVirtualMachineName {
            return
        }

        let legacyMachineDirectory = try FileUtilities.getLegacyApplicationSupportDirectory()

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(at: legacyMachineDirectory, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return
        }

        let virtualMachineDirectory = try getVirtualMachineDirectory(createIfNotExists: false)
        try FileManager.default.moveItem(at: legacyMachineDirectory, to: virtualMachineDirectory)
    }

    func setCurrentError(_ error: Error) {
        state = .error
        self.error = error
    }
}

enum CannedMacState {
    case unknown
    case error
    case downloadInstaller
    case installingMacOS
    case bootVirtualMachine
}
