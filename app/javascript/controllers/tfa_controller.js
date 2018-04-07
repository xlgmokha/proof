import { Controller } from 'stimulus'
import Tfa from '../models/tfa'

export default class extends Controller {
  get secret() { return this.targets.find("secret") }

  present() {
    //let tfa = new Tfa(this.secret.value);
    //console.log(tfa.qr_code());
    console.log("CLICKED");
  }
}
