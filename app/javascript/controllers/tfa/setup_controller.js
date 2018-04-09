import { Controller } from 'stimulus'
import QRCode from 'qrcode'

export default class extends Controller {
  get secret() { return this.targets.find("secret") }
  get canvas() { return this.targets.find("canvas") }

  connect() {
    QRCode.toCanvas(this.canvas, this.secret.value, (error) => {
      if (error) console.error(error);
    });
  }
}
