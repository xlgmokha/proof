import I18n from '../../app/javascript/i18n.js';

describe("I18n", () => {
  describe(".translate", () => {
    const subject = I18n;

    it("returns the correct translations for a nested value", () => {
      const result = subject.translate('application.navbar.home')
      expect(result).toEqual('Home')
    });
  });
});
