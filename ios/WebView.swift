class WebViewModel: ObservableObject {
    var receivedStringFromWeb = PassthroughSubject<String, Never>();
    var callbackValueFromNative = PassthroughSubject<String, Never>();
}

protocol WebViewHandlerDelegate {
    func receivedJsonValueFromWebView(value: String)
}

struct WebView: UIViewRepresentable, WebViewHandlerDelegate {
    func receivedJsonValueFromWebView(value: String) {
        self.model.receivedStringFromWeb.send(value)
    }

    let url: URL?
    @ObservedObject var model: WebViewModel
    let finishedLoading: Binding<Bool>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.userContentController.add(self.makeCoordinator(), name: "Native")

        let webview = WKWebView(frame: .zero, configuration: config)

        webview.navigationDelegate = context.coordinator
        webview.allowsBackForwardNavigationGestures = false
        webview.scrollView.isScrollEnabled = true

        return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let myUrl = url else {
            return
        }
        let request = URLRequest(url: myUrl)
        uiView.load(request)
    }

    class Coordinator : NSObject, WKNavigationDelegate {
        var parent: WebView
        var callbackValueFromNative: AnyCancellable? = nil

        var delegate: WebViewHandlerDelegate?

        init(_ uiWebView: WebView) {
            self.parent = uiWebView
            self.delegate = parent
        }

        deinit {
            callbackValueFromNative?.cancel()
        }

        func webView(_ webview: WKWebView, didFinish: WKNavigation!) {
            callbackValueFromNative = parent.model.callbackValueFromNative
                .receive(on: RunLoop.main)
                .sink(receiveValue: { value in
                    let js = "window.gotDataFromNative('" + value + "')"
                    webview.evaluateJavaScript(js)
                })

            if(webview.isLoading) {
                return
            }

            webview.evaluateJavaScript("document.readyState",
                completionHandler: { (result, error) in
                    self.parent.finishedLoading.wrappedValue = result as? String == "complete"
                })

        }
    }
}

extension WebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "Native" {
            delegate?.receivedJsonValueFromWebView(value: message.body as! String)
        }
    }
}
