// Karma configuration
// Generated on Sun Jan 28 2018 13:49:43 GMT-0700 (MST)

module.exports = function(config) {
  const tests = 'spec/javascripts/**/*.spec.js';
  config.set({
    basePath: '',
    frameworks: ['jasmine', 'fixture'],
    files: [
      tests,
      'spec/fixtures/**/*.html',
      'spec/fixtures/**/*.json',
      'node_modules/jquery/dist/jquery.min.js',
      'node_modules/jasmine-fixture/dist/jasmine-fixture.min.js'
    ],
    exclude: [ ],
    preprocessors: {
      'app/javascript/packs/*.js': ['webpack', 'sourcemap'],
      '**/*.html': ['html2js'],
      '**/*.json': ['json_fixtures'],
      [tests]: ['webpack', 'sourcemap']
    },
    reporters: ['mocha'],
    mochaReporter: {
      output: 'autowatch'
    },
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
