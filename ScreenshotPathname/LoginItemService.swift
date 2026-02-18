import Foundation
import ServiceManagement

final class LoginItemService {
    func currentStatus() -> SMAppService.Status {
        SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
