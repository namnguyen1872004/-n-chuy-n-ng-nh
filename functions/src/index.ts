import * as functions from "firebase-functions";
import * as crypto from "crypto";

// Secret key VNPay của merchant (giống Flutter)
const vnp_HashSecret = "20DKHTRD77WSJYU4JQX3RPX5SRCRVBLP";

/**
 * ✅ Cloud Function để VNPay gọi xác minh chữ ký
 * URL: https://us-central1-hoainam-ebcb8.cloudfunctions.net/vnpayReturn
 */
export const vnpayReturn = functions.https.onRequest((req, res) => {
  const vnpParams = req.query as Record<string, string>;

  const receivedHash = vnpParams["vnp_SecureHash"];
  delete vnpParams["vnp_SecureHash"];
  delete vnpParams["vnp_SecureHashType"];

  const sortedKeys = Object.keys(vnpParams).sort();
  const signData = sortedKeys.map((k) => `${k}=${vnpParams[k]}`).join("&");

  const hmac = crypto.createHmac("sha512", vnp_HashSecret);
  const signed = hmac.update(Buffer.from(signData, "utf-8")).digest("hex");

  if (signed === receivedHash) {
    console.log("✅ VNPay xác thực thành công:", vnpParams);
    res.status(200).send("Xác thực VNPay thành công ✅");
  } else {
    console.error("❌ VNPay sai chữ ký:", vnpParams);
    res.status(400).send("Sai chữ ký ❌");
  }
});
