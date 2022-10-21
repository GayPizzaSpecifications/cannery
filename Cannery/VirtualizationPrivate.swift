//
//  VirtualizationPrivate.swift
//  macOS
//
//  Created by Alex Zenla on 3/24/22.
//

#if CANNED_MAC_USE_PRIVATE_APIS
import Foundation
import Virtualization

@objc protocol _VZAppleTouchScreenConfiguration {
    init()
}

@objc protocol _VZUSBTouchScreenConfiguration {
    init()
}

@objc protocol _VZUSBMassStorageDeviceConfiguration {
    init(attachment: VZStorageDeviceAttachment)
}

@objc protocol _VZEFIBootLoader {
    init()

    var efiURL: URL { get }
    var VariableStore: _VZEFIVariableStore { get set }
}

@objc protocol _VZEFIVariableStore {
    init(url: URL) throws
}

@objc protocol _VZGDBDebugStubConfiguration {
    init(port: Int)
}

@objc protocol _VZVirtualMachineConfiguration {
    var _debugStub: _VZGDBDebugStubConfiguration { get @objc(_setDebugStub:) set }
    var _multiTouchDevices: [AnyObject] { get @objc(_setMultiTouchDevices:) set }
}

@objc protocol _VZVNCAuthenticationSecurityConfiguration {
    init(password: String)
}

@objc protocol _VZVNCNoSecuritySecurityConfiguration {
    init()
}

@objc protocol _VZVNCServer {
    init(port: Int, queue: DispatchQueue, securityConfiguration: AnyObject)

    var virtualMachine: VZVirtualMachine { get @objc(setVirtualMachine:) set }
    var port: Int { get }

    func start()
    func stop()
}

@objc protocol _VZPL011SerialPortConfiguration {
    init()
}

@objc protocol _VZ16550SerialPortConfiguration {
    init()
}

extension VZVirtualMachineConfiguration {
    func setGdbDebugStub(_ gdb: _VZGDBDebugStubConfiguration) {
        unsafeBitCast(self, to: _VZVirtualMachineConfiguration.self)._debugStub = gdb
    }
}

enum VZPrivateUtilities {
    static func createVncServer(port: Int, queue: DispatchQueue, password: String? = nil) -> _VZVNCServer {
        unsafeBitCast(NSClassFromString("_VZVNCServer")!, to: _VZVNCServer.Type.self).init(port: port, queue: queue, securityConfiguration: password != nil ? createVncServerAuthentication(password: password!) : createVncServerNoSecurity())
    }

    static func createVncServerNoSecurity() -> _VZVNCNoSecuritySecurityConfiguration {
        unsafeBitCast(NSClassFromString("_VZVNCNoSecuritySecurityConfiguration")!, to: _VZVNCNoSecuritySecurityConfiguration.Type.self).init()
    }

    static func createVncServerAuthentication(password: String) -> _VZVNCAuthenticationSecurityConfiguration {
        unsafeBitCast(NSClassFromString("_VZVNCAuthenticationSecurityConfiguration")!, to: _VZVNCAuthenticationSecurityConfiguration.Type.self).init(password: password)
    }

    static func createEfiBootLoader() -> _VZEFIBootLoader {
        unsafeBitCast(NSClassFromString("_VZEFIBootLoader")!, to: _VZEFIBootLoader.Type.self).init()
    }

    static func createGdbDebugStub(_ port: Int) -> _VZGDBDebugStubConfiguration {
        unsafeBitCast(NSClassFromString("_VZGDBDebugStubConfiguration")!, to: _VZGDBDebugStubConfiguration.Type.self).init(port: port)
    }

    static func createAppleTouchScreenConfiguration() -> _VZAppleTouchScreenConfiguration {
        unsafeBitCast(NSClassFromString("_VZAppleTouchScreenConfiguration")!, to: _VZAppleTouchScreenConfiguration.Type.self).init()
    }

    static func createUSBTouchScreenConfiguration() -> _VZUSBTouchScreenConfiguration {
        unsafeBitCast(NSClassFromString("_VZUSBTouchScreenConfiguration")!, to: _VZUSBTouchScreenConfiguration.Type.self).init()
    }

    static func addMultiTouchDeviceConfiguration(_ device: AnyObject, to configuration: VZVirtualMachineConfiguration) {
        unsafeBitCast(configuration, to: _VZVirtualMachineConfiguration.self)._multiTouchDevices = [device]
    }

    static func createPL011SerialPortConfiguration() -> VZSerialPortConfiguration {
        let serialPort = unsafeBitCast(NSClassFromString("_VZPL011SerialPortConfiguration")!, to: _VZPL011SerialPortConfiguration.Type.self).init()
        return unsafeBitCast(serialPort, to: VZSerialPortConfiguration.self)
    }

    static func create16550SerialPortConfiguration() -> VZSerialPortConfiguration {
        let serialPort = unsafeBitCast(NSClassFromString("_VZ16550SerialPortConfiguration")!, to: _VZ16550SerialPortConfiguration.Type.self).init()
        return unsafeBitCast(serialPort, to: VZSerialPortConfiguration.self)
    }

    static func createUSBMassStorageConfiguration(attachment: VZStorageDeviceAttachment) -> _VZUSBMassStorageDeviceConfiguration {
        unsafeBitCast(NSClassFromString("_VZUSBMassStorageDeviceConfiguration")!, to: _VZUSBMassStorageDeviceConfiguration.Type.self).init(attachment: attachment)
    }
}
#endif
