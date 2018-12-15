import validator from 'validator';

export default class Email {
  constructor(value) {
    this.value = value;
  }

  valid() {
    return validator.isEmail(this.value);
  }

  invalid() {
    return !this.valid();
  }
}
