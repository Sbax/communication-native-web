public class MainActivity extends AppCompatActivity {
    WebView myWebView;
    String TAG = "Webview Example";

    String interfaceName = "Android";

    @JavascriptInterface
    public void gotDataFromWeb(String string) {
        // uses <interfaceName>.gotDataFromWeb(string);
        try {
            JSONObject data = new JSONObject(string);
            String request = data.getString("request");

            switch (request) {
                case "NOTIFICATIONS_SUBSCRIBE":
                    if (!checkNotificationsStatus()) {
                        requestNotifications();
                    } else {
                        sendNotificationStatusToWeb(true);
                    }

                    break;
                case "NOTIFICATIONS_UNSUBSCRIBE":
                    revokeNotificationPermissions();
                    break;
                default:
                    break;
            }
        } catch (JSONException err) {
            Log.e(TAG, err.toString());
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        myWebView = (WebView) findViewById(R.id.webview);

        myWebView.setWebViewClient(new WebViewClient() {
            public void onPageFinished(WebView view, String url) {
                boolean permission = checkNotificationsStatus();
                try {
                    sendNotificationStatusToWeb(permission);
                } catch (Exception exception) {
                    Log.e(TAG, exception.toString());
                }
            }
        });

        WebSettings webSettings = myWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        myWebView.addJavascriptInterface(this, interfaceName);
        myWebView.loadUrl("http://10.0.2.2:3000");
    }

    private boolean checkNotificationsStatus() {
        // TODO add BE logic to check if the current device is subscribed
        return ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED;
    }

    private void requestNotifications() {
        try {
            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS);
            } else {
                showConfirmationModal();
            }
        } catch (Exception error) {
            Log.e(TAG, error.toString());
        }
    }

    private void grantNotificationPermissions() {
        // TODO add BE logic to subscribe the current device
        sendNotificationStatusToWeb(true);
    }

    private void revokeNotificationPermissions() {
        // TODO add BE logic to check if the current device is subscribed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            revokeSelfPermissionOnKill(Manifest.permission.POST_NOTIFICATIONS);
        }
        sendNotificationStatusToWeb(false);
    }

    private void sendNotificationStatusToWeb(boolean status) {
        try {
            JSONObject object = new JSONObject();
            object.put("notificationsEnabled", status);
            sendDataToWeb(object);
        } catch (Exception exception) {
            Log.e(TAG, exception.toString());
        }
    }

    private void showConfirmationModal() {
        this.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                AlertDialog.Builder alert = new AlertDialog.Builder(MainActivity.this);
                alert.setTitle("Notifications");
                alert.setMessage("Are you sure you want to enable notifications?");
                alert.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        grantNotificationPermissions();
                        dialog.dismiss();
                    }
                }).setNegativeButton("No", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        dialog.dismiss();
                    }
                });

                alert.show();
            }
        });
    }

    public void sendDataToWeb(JSONObject object) {
        // need to define a gotDataFromNative method on web codebase
        this.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                myWebView.evaluateJavascript("window.gotDataFromNative('" + object.toString() + " ')", new ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String response) {
                        Log.d(TAG, response);
                    }
                });
            }
        });
    }


    private ActivityResultLauncher<String> requestPermissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestPermission(), isGranted -> {
                if (isGranted) {
                    grantNotificationPermissions();
                }
            });
}