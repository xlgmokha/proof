// Karma configuration
// Generated on Sun Jan 28 2018 13:49:43 GMT-0700 (MST)

module.exports = function(config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine'],
    files: [
      'spec/javascripts/**/*.spec.js',
      'node_modules/jquery/dist/jquery.min.js',
      'node_modules/jasmine-fixture/dist/jasmine-fixture.min.js'
    ],
    exclude: [ ],
    preprocessors: {
      'app/javascript/packs/*.js': ['webpack', 'sourcemap'],
      'spec/javascripts/**/*.spec.js': ['webpack', 'sourcemap']
    },
    reporters: ['mocha'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['ChromeHeadless'],
    singleRun: true,
    concurrency: Infinity,
    webpack: require('./config/webpack/test.js'),
    webpackMiddleware: {
      stats: 'errors-only'
    }
  })
}
