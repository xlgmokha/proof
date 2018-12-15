import Controller from '../../../app/javascript/controllers/input_controller'
import { Application } from 'stimulus';

describe('input', () => {
  beforeEach(() => {
    fixture.setBase('spec/fixtures')
    const el = fixture.load('input.html')

    const application = new Application();
    application.router.start();
    application.dispatcher.start();
    application.register('input', Controller);
  });

  afterEach(() => {
    fixture.cleanup();
  });

  it("displays an error message next to the field", () => {
    const nameElement = document.querySelector('#name')
    nameElement.value = ''
    nameElement.dispatchEvent(new Event('keyup'));

    const errorElement = document.querySelector('#name-error')
    expect(errorElement.textContent).toEqual('is required')

    const helpElement = document.querySelector('#name-help-block')
    expect(helpElement.classList.contains('hide')).toEqual(false)
  });

  it("disables the submit button, one one field is valid and the other is not", () => {
    let nameElement = document.querySelector('#name');
    nameElement.value = '';
    nameElement.dispatchEvent(new Event('keyup'));
    expect(nameElement.getAttribute('data-input-valid')).toEqual('false')

    let emailElement = document.querySelector('#email');
    emailElement.value = 'test@example.org';
    emailElement.dispatchEvent(new Event('keyup'));
    expect(emailElement.getAttribute('data-input-valid')).toEqual('true')

    const submitButton = document.querySelector('#submit-button')
    expect(submitButton.getAttribute('disabled')).toEqual('disabled')
  });

  it('disables the submit button, when a field does not meet the minLength', () => {
    document.querySelector('#email').value = 'test@example.org';
    let nameElement = document.querySelector('#name');
    nameElement.value = '12';
    nameElement.dispatchEvent(new Event('keyup'));
    expect(nameElement.getAttribute('data-input-valid')).toEqual('false')

    const submitButton = document.querySelector('#submit-button')
    expect(submitButton.getAttribute('disabled')).toEqual('disabled')
  });

  it('disables the submit button, when a field exceeds the maxLength', () => {
    document.querySelector('#email').value = 'test@example.org';

    let nameElement = document.querySelector('#name');
    nameElement.value = '1234567890';
    nameElement.dispatchEvent(new Event('keyup'));
    expect(nameElement.getAttribute('data-input-valid')).toEqual('false')

    const submitButton = document.querySelector('#submit-button')
    expect(submitButton.getAttribute('disabled')).toEqual('disabled')
  });

  it("disables the submit button, when the password does not match the confirmation", () => {
    document.querySelector('#email').value = 'test@example.org';
    document.querySelector('#name').value = 'Tsuyoshi';

    const passwordElement = document.querySelector('#password')
    passwordElement.value = "PASSWORD"

    const confirmationElement = document.querySelector('#password_confirmation')
    confirmationElement.value = "NOT PASSWORD"
    confirmationElement.dispatchEvent(new Event('keyup'));

    expect(confirmationElement.getAttribute('data-input-valid')).toEqual('false')

    const submitButton = document.querySelector('#submit-button')
    expect(submitButton.getAttribute('disabled')).toEqual('disabled')
  });

  it("is invalid, when the email is not valid", () => {
    const emailElement = document.querySelector('#email')
    emailElement.value = 'invalid';
    emailElement.dispatchEvent(new Event('keyup'));
    expect(emailElement.getAttribute('data-input-valid')).toEqual('false')
  });

  it('enables the submit button, when the fields are valid', () => {
    document.querySelector('#email').value = 'test@example.org';
    document.querySelector('#password').value = 'password';
    document.querySelector('#password_confirmation').value = 'password';

    let nameElement = document.querySelector('#name');
    nameElement.value = '';
    nameElement.dispatchEvent(new Event('keyup'));

    nameElement.value = 'Tsuyoshi';
    nameElement.dispatchEvent(new Event('keyup'));
    expect(nameElement.getAttribute('data-input-valid')).toEqual('true')

    const submitButton = document.querySelector('#submit-button')
    expect(submitButton.getAttribute('disabled')).toEqual(null)
  });

  it('hides error messages, when the fields are valid', () => {
    document.querySelector('#email').value = 'test@example.org';
    document.querySelector('#password').value = 'password';
    document.querySelector('#password_confirmation').value = 'password';

    let nameElement = document.querySelector('#name');
    nameElement.value = '';
    nameElement.dispatchEvent(new Event('keyup'));

    nameElement.value = 'Tsuyoshi';
    nameElement.dispatchEvent(new Event('keyup'));

    const helpElement = document.querySelector('#name-help-block')
    expect(helpElement.classList.contains('hide')).toEqual(true)

    const errorElement = document.querySelector('#name-error')
    expect(errorElement.textContent).toEqual('')
  });
});
