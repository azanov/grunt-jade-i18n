path = require 'path'
_ = require 'lodash'

module.exports = (grunt) ->

  grunt.loadNpmTasks 'grunt-contrib-jade'
  grunt.renameTask 'jade', 'contrib-jade'

  grunt.registerMultiTask 'jade', 'Compile Jade template with internalization support', ->
    
    jadeConfig = null
    jadeOrigConfig = grunt.config.get('jade')[@target]

    options = @options()
    options.i18n = {} unless options.i18n
    { locales, namespace, locateExtension, defaultExt } = options.i18n
    
    # set default options
    namespace = '$i18n' unless namespace?
    locateExtension = no unless locateExtension?
    defaultExt = 'html' unless defaultExt?

    if locales and locales.length
      jadeConfig = {}

      grunt.file.expand(locales).forEach (filepath) =>

        # get the language code
        fileExt = filepath.split('.').slice(-1)[0]
        locale = path.basename filepath, '.' + fileExt
        grunt.verbose.writeln "Loading locate '#{locale}'"
        
        # create the new config as subtask for each language, based on the original task config
        jadeConfig["#{@name}-#{locale}"] = config = _.cloneDeep jadeOrigConfig
        
        # read data from translation file
        grunt.verbose.writeln "Reading translation data: #{filepath}"
        
        opts = config.options = if not config.options then {} else config.options 
        opts.data = opts.data() or {} if typeof opts.data is 'function'
        opts.data = {} unless _.isPlainObject opts.data
        opts.data = _.extend opts.data, readFile filepath
        opts.data[namespace] = readFile filepath
        
        # translate output destination for each language
        config.files = _.cloneDeep(@files).map (file) ->
          if locateExtension
            addLocateExtensionDest file, locale, defaultExt
          else
            addLocateDirnameDest file, locale, defaultExt
          file

    else
      grunt.log.writeln 'Locales files not found. Nothing to translate'
 
    # set the extended config object to the original Jade task
    grunt.config.set 'contrib-jade', jadeConfig or jadeOrigConfig

    # finally run the original Jade task
    grunt.task.run 'contrib-jade'



  getExtension = (filepath) ->
    path.extname filepath

  addLocateExtensionDest = (file, locale, outputExt) ->
    locale = locale.toLowerCase()
    getBaseName = -> path.basename(file.src[0]).split('.')[0]

    if ext = getExtension file.dest
      dest = path.join path.dirname(file.dest), path.basename(file.dest, ext) + ".#{locale}"
    else 
      dest = path.join file.dest, getBaseName() + ".#{locale}"

    if file.orig.ext
      dest += file.orig.ext
    else
      dest += '.' + outputExt
      
    file.dest = file.orig.dest = dest

  addLocateDirnameDest = (file, locale, outputExt) ->
    if ext = getExtension file.dest
      dest = path.join path.dirname(file.dest), locale, path.basename(file.dest, ext) + ext
    else
      if /(\/|\*+)$/i.test file.dest
        base = file.dest.split('/')
        dest = path.join path.join.apply(null, base.slice(0, -1)), locale, base.slice(-1)[0]
      else
        dest = path.join file.dest, locale

    dest = dest.replace /\.jade$/i, '.' + outputExt
    file.dest = file.orig.dest = dest

  readFile = (filepath) ->
    try 
      if /(\.yaml|\.yml)$/i.test filepath
        data = grunt.file.readYAML filepath
      else if /\.js$/i.test filepath
        data = require path.resolve filepath
      else
        data = grunt.file.readJSON filepath
    catch e
      grunt.fail.warm "Cannot parse locate file '#{filepath}': #{e.message}", 3

    data