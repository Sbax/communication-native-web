# Native to Web

Define `window.gotDataFromNative` function, this should receive JSON strings from Native

# Web to Native

Define `window.sendDataToNative` as it follows

```js
window.sendDataToNative = (request: Request) => {
  const string = JSON.stringify(request);

  // Android
  const Android = window.Android;
  if (typeof Android !== "undefined") {
    Android.gotDataFromWeb(string);
  }

  // iOS
  if (window.webkit?.messageHandlers?.Native) {
    window.webkit.messageHandlers.Native.postMessage(string);
  }
};
```
