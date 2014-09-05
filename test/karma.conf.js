// Karma configuration
// Generated on Tue May 13 2014 12:20:09 GMT+0800 (CST)

module.exports = function(config) {
  var configuration = {

    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '../',


    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['mocha', 'expect'],


    // list of files / patterns to load in the browser
    files: [
      'test/unit/**/*.ls',

      // Fixtures
      'test/fixtures/*.xml',
      'test/fixtures/*.html',
      'test/fixtures/*.css',
      {pattern: 'test/fixtures/*.jpg',  watched: false, included: false, served: true},

      // Filename placeholders
      {pattern: 'test/fixtures/PLACEHOLDER',  watched: false, included: false, served: true}
    ],


    // list of files to exclude
    exclude: [

    ],


    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      '**/*Spec.ls': ['webpack'],
      '**/*.html':['html2js'],
      '**/*.json':['html2js'],
      '**/*.xml':['html2js']
    },

    webpack: {
        cache: true,
        module: {
          loaders: [{
              test: /\.ls$/,
              loader: 'livescript'
          },{
              test: /\.coffee$/,
              loader: 'coffee-loader'
          }]
        }
    },

    // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['mocha'],


    // web server port
    port: 9876,


    // enable / disable colors in the output (reporters and logs)
    colors: true,


    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,


    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    // browsers: ['Chrome', 'Safari', 'Firefox'],
    browsers: ['Chrome'],
    // browsers: ['ChromeCanary'],

    customLaunchers: {
      Chrome_travis_ci: {
        base: 'Chrome',
        flags: ['--no-sandbox']
      }
    },


    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    singleRun: false
  };

  if(process.env.TRAVIS){
    configuration.browsers = ['Chrome_travis_ci'];
    // configuration.reporters = configuration.reporters.concat(['coverage', 'coveralls']);
    // configuration.coverageReporter = {
    //   type : 'lcovonly',
    //   dir : 'coverage/'
    // };
  }

  config.set(configuration);
};
