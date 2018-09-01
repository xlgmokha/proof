import ApplicationController from '../application_controller';
import QRCode from 'qrcode';

export default class extends ApplicationController {
  get secret() { return this.targets.find('secret'); }

  get canvas() { return this.targets.find('canvas'); }

  connect() {
    QRCode.toCanvas(this.canvas, this.secret.value, (error) => {
      if (error) super.log(error);
    });
  }
}
