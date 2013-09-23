# CONFIGURATION
# ===============

CSV_SEPARATOR = ";"
MIN_YEAR = 1970
MAX_YEAR = 2012

##
# Wait until the test condition is true or a timeout occurs. Useful for waiting
# on a server response or for a ui change (fadeIn, etc.) to occur.
#
# @param testFx javascript condition that evaluates to a boolean,
# it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
# as a callback function.
# @param onReady what to do when testFx condition is fulfilled,
# it can be passed in as a string (e.g.: "1 == 1" or "$('#bar').is(':visible')" or
# as a callback function.
# @param timeOutMillis the max amount of time to wait. If not specified, 3 sec is used.
##
waitFor = (testFx, onReady, timeOutMillis=3000) ->
  start = new Date().getTime()
  condition = false
  f = ->
    if (new Date().getTime() - start < timeOutMillis) and not condition
      # If not time-out yet and condition not yet fulfilled
      condition = (if typeof testFx is 'string' then eval testFx else testFx()) #< defensive code
    else
      if not condition
        # If condition still not fulfilled (timeout but condition is 'false')
        console.log "'waitFor()' timeout"
        phantom.exit 1
      else
        # Condition fulfilled (timeout and/or condition is 'true')
        console.log "'waitFor()' finished in #{new Date().getTime() - start}ms."
        if typeof onReady is 'string' then eval onReady else onReady() #< Do what it's supposed to do once the condition is fulfilled
        clearInterval interval #< Stop this interval
  interval = setInterval f, 250 #< repeat check every 250ms

#
fs   = require('fs')
page = require('webpage').create()
page.viewportSize = { width: 1400, height: 800 }
page.settings.userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36'

#
page.onConsoleMessage = (msg, line, file)->
  console.log msg

page.onError = (msg, trace) ->
  console.log msg
  for item in trace
    console.log "  #{item.file}:#{item.line}"

page.onAlert = (msg) ->
  if /Your query did not return any results/.test(msg)
    checkForNextStep()
  else
    console.log "\n\nALERT:#{msg}\n\n"
    phantom.exit()


page.onLoadStarted = ->
  console.log("\nloading page…")

nextStep = null
page.onLoadFinished = ->
  console.log("page loaded.\n")
  # resetTimeout()
  # if nextStep
  #   nextStep()


# get urls
dataFile      = './urls.txt'
resultsFile   = './results.csv'
urls          = fs.read(dataFile).split(/\n/)
csvColumns    = ["main_url", "version", "API version", "Email Address"]

# cleanup
fs.remove "debug.png" if fs.exists "debug.png"
fs.remove resultsFile if fs.exists resultsFile

# start new CSV
fs.write resultsFile, csvColumns.join( CSV_SEPARATOR ), 'a'


openNextUrl = ->
  phantom.exit() if urls.length is 0
  currentUrl = urls.shift()

  console.log "opening #{currentUrl}"
  page.open currentUrl, (status) ->
    if status isnt 'success'

      console.log "\n============================================="
      console.log "Something wen't wrong: #{status}"
      console.log 'Unable to access ' + START_URL
      console.log "=============================================\n"
      phantom.exit()

    else
      console.log "loaded #{currentUrl}"

      email = page.evaluate ->
        try
          return $('a[href^=mailto]').text()
        catch e
          return 'error'

      if email is 'error'
        console.log "jQuery not available at #{currentUrl}"
        doScreenshot currentUrl
        return openNextUrl()

      unless email
        console.log "email could not be found at #{currentUrl}"
        doScreenshot currentUrl
        return openNextUrl()

      version = page.evaluate ->
        version = 0
        $.ajax
          async: false,
          url: '/api?task=version',
          success: (data) ->
            if typeof data is 'string'
              data = JSON.parse data
            version = data.payload.version[0].version
          error: (error) ->
            console.log "error loading"
        return version

      row = [
        currentUrl
        version
        version
        email
      ].join(CSV_SEPARATOR)
      fs.write resultsFile, "\n#{row}" , 'a'

      unless email
        doScreenshot currentUrl
      openNextUrl()

doScreenshot = (url) ->
  fileName = url.replace /^https?:\/\//, ''
  fileName = fileName.replace /[^\w]/g, ''
  fileName = "screenshots/#{fileName}.png"
  page.render fileName
  console.log "created screenshot at #{fileName}"
openNextUrl()