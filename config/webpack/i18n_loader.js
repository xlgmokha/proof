"use strict";

const _ = require("lodash");
const glob = require("glob");
const path = require("path");
const fs = require("fs");
const yaml = require("yaml-js");

class I18nLoader {
  constructor(localesPath, pattern) {
    this.localesPath = localesPath || '';
    this.pattern = pattern || "**/*.yml";
  }

  fetch() {
    let content = {};
    _.forEach(glob.sync(this.pattern, { cwd: this.localesPath }), (file) => {
      let translations = this.fromFile(file);
      _.forEach(translations, (pairs, locale) => {
        if (!content[locale]) { content[locale] = {}; }
        _.assign(content[locale], pairs);
      });
    });
    return content;
  }

  fromFile(file) {
    let content = yaml.load(fs.readFileSync(path.join(this.localesPath, file)));
    _.forEach(content, (data, locale) => {
      content[locale] = I18nLoader.flatten(data);
    });
    return content;
  }

  static flatten(data, prefix = null) {
    let result = [];
    _.forEach(data, (value, key) => {
      let prefixKey = prefix ? `${prefix}.${key}` : key;
      if (_.isPlainObject(value)) {
        _.assign(result, I18nLoader.flatten(value, prefixKey));
      } else {
        result[prefixKey] = value;
      }
    });
    return result;
  }
}

module.exports = I18nLoader;
