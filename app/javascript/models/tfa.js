export default class Tfa {
  constructor(secret) {
    this.secret = secret;
  }

  qr_code() {
    return "hello world";
  }
}
