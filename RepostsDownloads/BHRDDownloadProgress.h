#import "../JGProgressHUD/JGProgressHUD.h"
JGProgressHUD *BHRDShowDownloadProgress(NSString *title, void (^cancel)(void));
void BHRDUpdateDownloadProgress(JGProgressHUD *hud, NSString *detail);
void BHRDDismissDownloadProgress(JGProgressHUD *hud);
