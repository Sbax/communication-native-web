struct ContentView: View {
    @StateObject var model = WebViewModel()
    @State var webViewFinishedLoading = false
    @State private var info: AlertInfo?

    var body: some View {
        VStack {
            WebView(url: URL(string: "http://127.0.0.1:3000"), model: model, finishedLoading: $webViewFinishedLoading)
                .onChange(of: webViewFinishedLoading, perform: {value in
                    if(webViewFinishedLoading) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // onLoad event is called too soon so we need a small delay
                            checkNotificationsStatus()
                        }
                    }
                })
                .onReceive(model.receivedStringFromWeb, perform: { receivedStringFromWeb in
                    let jsonData = Data(receivedStringFromWeb.utf8);
                    let decoder = JSONDecoder()
                    do {
                        let message = try decoder.decode(Request.self, from: jsonData)
                        switch (message.request) {
                        case "NOTIFICATIONS_UNSUBSCRIBE":
                            revokeNotificationsPermissions()
                            break
                        case "NOTIFICATIONS_SUBSCRIBE":
                            requestNotifications()
                            break
                        default:
                            break
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                })
        }.alert(item: $info, content: { info in
            Alert(title: Text(info.title),
                message: Text(info.message)
            )})
    }

    func checkNotificationsStatus() -> Void {
        let current = UNUserNotificationCenter.current()
        
        current.getNotificationSettings(completionHandler: { (settings) in
            let status = settings.authorizationStatus == .authorized
            sendNotificationsStatusToWeb(status: status)
        })
    }

    func requestNotifications() -> Void {
        let current = UNUserNotificationCenter.current()

        current.getNotificationSettings(completionHandler: { (settings) in
            if settings.authorizationStatus == .notDetermined {
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .sound]){ (granted, error) in
                    guard error == nil && granted else {
                        // User denied permissions, or error occurred
                        return
                    }

                    grantNotificationsPermissions();
                }
            } else if settings.authorizationStatus == .denied {
                info = AlertInfo(
                    id: .one,
                    title: "Warning",
                    message: "Notifications were previously denied, please refer to your device settings to grant notification permissions")
                
            } else {
                grantNotificationsPermissions()
            }
        })
    }

    func grantNotificationsPermissions() -> Void {
        // TODO add BE logic to subscribe the current device
        sendNotificationsStatusToWeb(status: true)
    }

    func revokeNotificationsPermissions() -> Void {
        // TODO add BE logic to unsubscribe the current device
        info = AlertInfo(
            id: .one,
            title: "Warning",
            message: "Notifications were previously granted, please refer to your device settings to revoke notification permissions")
    }

    func sendNotificationsStatusToWeb(status: Bool) -> Void {
        model.callbackValueFromNative.send("{\"notificationsEnabled\":" + String(status) + "}")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Request: Codable {
    var request: String
    var payload: String?
}

struct AlertInfo: Identifiable {
    enum AlertType {
        case one
        case two
    }

    let id: AlertType
    let title: String
    let message: String
}
