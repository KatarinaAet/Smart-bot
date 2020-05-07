querystring = require 'querystring'
HUBOT_JENKINS_URL = 'https://path/to/jenkins'
HUBOT_JENKINS_AUTH = 'username:token'
CURRENT_VERSION = '2020.1'
arrayApps1 = ["app1", "app11", "app111"]
arrayApps2 = ["app2", "app22", "app222"]
arrayEnv = ["env1", "env2", "env3"]

jenkinsParseParams = (msg) ->
  inputParams = String(msg.match[0]).split(" ")
  lastParam = inputParams[inputParams.length-1]
  if lastParam == ""
    sendFormatted(msg, "Error in string!!! Please remove space at the end of your statement.")
  else
    apps = ""
    if lastParam.toUpperCase()
      env = lastParam.toUpperCase()
      branch = "develop"
      for i in [1..inputParams.length-2]
        apps += inputParams[i].toLowerCase()
        if !inputParams[i].includes(",") && i != inputParams.length-2 || inputParams[i].includes(",") && inputParams[i].indexOf(",") != inputParams[i].length-1 && i != inputParams.length-2
          apps = ","
      jenkinsChooseStartJob(msg, apps, env, branch)
    else
      branch = lastParam
      env = inputParams[inputParams.length-2].toUpperCase()
      if env in arrayEnv
        for i in [1..inputParams.length-3]
          apps += inputParams[i].toLowerCase()
          if !inputParams[i].includes(",") && i != inputParams.length-3 || inputParams[i].includes(",") && i != inputParams.length-3 && inputParams[i].indexOf(",") != inputParams[i].length-1
            apps = ","
          jenkinsChooseStartJob(msg, apps, env, branch)
      else
        sendFormatted(msg, "Incorrect env: #{env}!!! Try again.")
        
jenkinsChooseStartJob = (msg, apps, env, branch) ->
  parseResponse = apps.split(",")
  for i in [0..parseResponse.length-1]
    if parseResponse[i] in arrayApps1
      if i != parseResponse.length-1
        continue
      else
        jenkinsMakeBuild1(msg, apps, env, branch)
    else if parseResponse[i] in arrayApps2
      if i != parseResponse.length-1
        continue
      else
        jenkinsMakeBuild2(msg, apps, env, branch)
    else
      sendFormatted(msg, "Sorry, I can't recongnize app: #{parseResponse[i]}<br/>
      Please, make sure you enter app correctly<br/>.")
      break
      
jenkinsMakeBuild1 = (msg, apps, env, branch) ->
  buildJobName = "make_build_job1"
  url = HUBOT_JENKINS_URL
  baseUrl = "#{url}job/#{buildJobName}"
  path = "#{baseUrl}/buildWithParameters?branch=#{branch}&apps=#{apps}&Deploy_to=#{env}&version=#{CURRENT_VERSION}"
  sendFormatted(msg, "Starting build #{buildJobName} apps: #{apps} to #{env} on #{branch}")
  requestDone = false
  buildFailed = false
  req = msg.http(path, rejectUnathorized: false)
  auth = new Buffer(HUBOT_JENKINS_AUTH).toString('base64')
  req.headers Authorization: "Basic #{auth}"
  req.header('Content-Length', 0)
  req.post() (err, res, body) ->
    if err
      sendFormatted(msg, "Jenkins says: #{err}")
    else if 200 <= res.statusCode < 400
      sendFormatted(msg, "Build started ( <a href=\"#{baseUrl}\"/> ) with params {#{branch}, #{CURRENT_VERSION}, deploy #{apps} to #{env}}")
      getBuildNumber(buildJobName, msg, baseUrl, apps, env)
    else if 404 == res.statusCode
      sendFormatted(msg, "Build not found, double check that it exists and is spell correctly.")
    else
      sendFormatted(msg, "Jenkins says: Status #{res.statusCode} #{body}")
      
jenkinsMakeBuild2 = (msg, apps, env, branch) ->
  buildJobName = "make_build_job2"
  url = HUBOT_JENKINS_URL
  baseUrl = "#{url}job/#{buildJobName}"
  path = "#{baseUrl}/buildWithParameters?branch=#{branch}&apps=#{apps}&Deploy_to=#{env}&version=#{CURRENT_VERSION}"
  sendFormatted(msg, "Starting build #{buildJobName} apps: #{apps} to #{env} on #{branch}")
  requestDone = false
  buildFailed = false
  req = msg.http(path, rejectUnathorized: false)
  auth = new Buffer(HUBOT_JENKINS_AUTH).toString('base64')
  req.headers Authorization: "Basic #{auth}"
  req.header('Content-Length', 0)
  req.post() (err, res, body) ->
    if err
      sendFormatted(msg, "Jenkins says: #{err}")
    else if 200 <= res.statusCode < 400
      sendFormatted(msg, "Build started ( <a href=\"#{baseUrl}\"/> ) with params {#{branch}, #{CURRENT_VERSION}, deploy #{apps} to #{env}}")
      getBuildNumber(buildJobName, msg, baseUrl, apps, env)
    else if 404 == res.statusCode
      sendFormatted(msg, "Build not found, double check that it exists and is spell correctly.")
    else
      sendFormatted(msg, "Jenkins says: Status #{res.statusCode} #{body}")
      
getBuildNumber = (job, msg, baseUrl, apps, env) ->
  attempt = 0
  console.log "Launch getBuildNumber..."
  urlToHttp = "#{baseUrl}/api/json"
  req = msg.http(urlToHttp)
  req.get() (err, res, body) ->
    if err
      console.log "error inside getBuildNumber"
    else
      response = ""
      try
        waitFor 2000
        content = JSON.parse(body)
        next_build_number = content.nextBuildNumber
        console.log "NEXT "+next_build_number
        console.log "Wait for Jenkins to start build"
        waitFor 1000
        waitForBuildComplete(job, next_build_number, msg, baseUrl, attempt, apps, env)
        
waitForBuildComplete = (job, number, msg, baseUrl, attempt, apps, env) ->
  url = HUBOT_JENKINS_URL
  result = ""
  console.log "NUMBER IS "+number
  inProgress = false
  console.log "attempt: "+attempt
  if attempt < 200
    urlToHttp = "#{baseUrl}/lastBuild/api/json"
    console.log "In waitForBuildComplete: #{urlToHttp}"
    req = msg.http(urlToHttp)
    req.post() (err, res, body) ->
      if err
        sendFormatted(msg, "Jenkins says: #{err}")
      else
        try
          console.log "Sleeping..."
          waitFor 20000
          console.log "Finish sleeping..."
          content = JSON.parse(body)
          console.log "CONTENT NUMBER "+content.number
          if (number == content.number)
            console.log "Number of builds are equal!"
            inProgress = content.building
            console.log "Content building "+content.building
            console.log "inProgress: "+inProgress
            result = content.result
            if inProgress == true
              console.log "next attempt..."
              waitForBuildComplete(job, number, msg, baseUrl, attempt+1, apps, env)
            else if (result.includes("ABORTED"))
              sendFormatted(msg, "#{job} <a href=\"#{url}job/#{job}/#{number}\"/> has been aborted.<br/>What should I do now?")
            else if (result.includes("FAILURE"))
              sendFormatted(msg, "#{job} finished with status: #{result}. Path: <a href=\"#{url}job/#{job}/#{number}\"/>")
            else if (result.includes("SUCCESS"))
              sendFormatted(msg, "#{job} finished with status: #{result}. Path: <a href=\"#{url}job/#{job}/#{number}\"/>")
              getAllDownStreamJob(msg, job, number, apps, env)
            else
              sendFormatted(msg, "I got something strange at the end of job.")
          else if (content.number < number)
            sendFormatted(msg, "Wait for availiable executor.<br/>I stop monitoring that build.<br/>What should I do now?")
          else
            sendFormatted(msg, "Someone has started that job before you.")
  else
    sendFormatted(msg, "Too many unsuccessful attempts.")

getAllDownStreamJob = (msg, job, num, apps, env) ->
  console.log "In getAllDownStreamJob "+num
  url = HUBOT_JENKINS_URL
  path = "#{url}job/#{job}/api/json"
  req = msg.http(path)
  req.get() (err, res, body) ->
    if err
      sendFormatted(msg, "Jenkins says: #{err}")
    else
      content = JSON.parse(body)
      len = content.downStreamProjects.length
      i = 0
      checkStatusOfDownStreamJob(content, job, "", msg, num, apps, env, i, len)

checkStatusOfDownStreamJob = (content2, upJob, downJob, msg, num, apps, env, i, len) ->
  console.log "incoming job "+downJob
  if i < len
    downJob = content2.downStreamProjects[i].name
    console.log "DownStream Job is "+downJob
    attempt = 0
    url = HUBOT_JENKINS_URL
    baseUrl = "#{url}job/#{downJob}"
    sendFormatted(msg, "Starting #{downJob} #{apps} to #{env}")
    console.log "Number of upstream job: "+num
    path = "#{baseUrl}/lastBuild/api/json"
    req = msg.http(path)
    req.post() (err, res, body) ->
      if err
        sendFormatted(msg, "Jenkins says: #{err}")
      else 
        try
          item = 0
          content = JSON.parse(body)
          if (upJob.includes("make_build_job1"))
            console.log "Job check passed"
            item = 1
          else if (upJob.includes("make_build_job2"))
            item = 2
          upstreamJobName = content.actions[item].causes[0].upstreamProject
          console.log "upstreamJobName "+upstreamJobName
          upStreamBuildNumber = content.actions[item].causes[0].upstreamBuild
          console.log "upstreamBuildNumber "+upStreamBuildNumber
          if (upstreamJobName.includes(upJob) && upStreamBuildNumber == num)
            console.log "It's alright! No other builds were started"
            waitForDownStreamToComplete(content2, content.number, msg, baseUrl, attempt, upJob, num, apps, env, i, len)
          else if ((upstreamJobName.includes("make_build_job1") || upstreamJobName.includes("make_build_job2")) && upStreamBuildNumber < num)   
            sendFormatted(msg, "Build of upstream job has not started yet. I stop monitoring that build.<br/>")
            checkStatusOfDownStreamJob(content2, upJob, downJob, msg, num, apps, env, i+1, len)
  else
    sendFormatted(msg, "All downstream jobs of #{upJob} finished.<br/>What should I do now?")

waitForDownStreamToComplete = (content2, number, msg, baseUrl, attempt, upJob, num, apps, env, i, len) ->
  console.log "Attempt of DS: "+attempt
  url = HUBOT_JENKINS_URL
  inProgress = false
  console.log "Attempt: "+attempt
  if attempt < 200
    urlToHttp = "#{baseUrl}/lastBuild/api/json"
    console.log "In waitForBuildComplete: #{urlToHttp}"
    req = msg.http(urlToHttp)
    req.post() (err, res, body) ->
      if err
        sendFormatted(msg, "Jenkins says: #{err}")
      else
        try
          console.log "Sleeping..."
          waitFor 20000
          console.log "Finish sleeping..."
          content = JSON.parse(body)
          if (number == content.number)
            console.log "Number of builds are equal"
            inProgress = content.building
            console.log "In progress "+inProgress
            result = content.result
            if inProgress == true       
              console.log "next attempt..."
              waitForDownStreamToComplete(content2, number, msg, baseUrl, attempt+1, upJob, num, apps, env, i, len)
            else
              sendFormatted(msg, "<a href=\"#{baseUrl}/#{number}\"/> finished with status: #{result}.")
              checkStatusOfDownStreamJob(content2, upJob, "", msg, num, apps, env, i+1, len)
          else if (number > content.number)
            sendFormatted(msg, "Wait for availiable executor.<br/>I stop monitoring that build.<br/>What should I do now?")
  else
    sendFormatted(msg, "Request timed out.<br/>What should I do now?")

jenkinsLast = (msg) ->
  url = HUBOT_JENKINS_URL
  jobPath = querystring.escape msg.match[1]
  str = String(msg.match[0]).split(" ")
  jobPath = str[1]
  path = "#{url}job/#{jobPath}/lastBuild/api/json"
  req = msg.http(path, rejectUnathorized: false)
  auth = new Buffer(HUBOT_JENKINS_AUTH).toString('base64')
  req.headers Authorization: "Basic #{auth}"
  req.header('Content-Length', 0)
  req.get() (err, res, body) ->
    if err 
      sendFormatted(msg, "Jenkins says: #{err}")
    else
      response = ""
      try
        content = JSON.parse(body)
        contentUrl = content.url
        response += "NAME: #{content.fullDisplayName}\n"
        if content.description
          response += "DESCRIPTION: #{content.description}\n"
        response += "BUILDING: #{content.building}\n"
        response += "RESULT: #{content.result}\n"
        sendFormatted(msg, "URL: <a href=\"#{contentUrl}\"/> #{response}.") 

jenkinsShowCurrentVersion = (msg) ->
  sendFormatted(msg, "Current version is #{CURRENT_VERSION}.")

jenkinsChangeCurrentVersion = (msg) ->
  str = String(msg.match[0]).split(" ")  
  CURRENT_VERSION = str[2]
  sendFormatted(msg, "Version changed to #{CURRENT_VERSION}.")
  
jenkinsHello = (msg) ->
  sendFormatted(msg, "Hello!<br/>I'm chat-bot.<br/>I can build and deploy different apps(to all env).<br/>Current /version is #{CURRENT_VERSION}.<br/>See /help for list of all commands.")
  
jenkinsHelp = (msg) ->
  sendFormatted(msg, "<b><i>/deploy app1, app11 env1</i></b> - build (from develop) and deploy app1 and app11 to env1.<br/>
  <b>Supported apps:</b><br/>
  1. #{arrayApps1}<br/>
  2. #{arrayApps2}<br/>
  <b>Supported env:</b><br/>
  #{arrayEnv}<br/>
  <b><i>/deploy app1, app11 env1 branch1</i></b> - build (from branch1) and deploy app1 and app11 to env1.<br/>
  <b><i>/update app1, app11 env1</i></b> - same as /deploy.<br/>
  <b><i>/version</i></b> - show current version<br/>
  <b><i>/set version 2020.2</i></b> - change current version<br/>
  <b><i>/last JOBNAME</i></b> - get number of last build, path, status(building or not) and result of building<br/>
  <b><i>/help</i></b> - show help")  
  
sleep = (ms) ->
  date = new Date()
  loop
    break if (new Date())-date > ms
    
doSafe = (msg, fun) ->
  try
    fun(msg)
  catch e
    console.log e
    sendFormatted(msg, "Got exception: #{e.stack}")
    
waitFor = (ms) ->
  seconds = ms / 1000
  for i in [0..seconds]
    sleep 1000
    
sendFormatted = (msg, text) ->
  msg.send "<messageML><p style=\"color:#4361EE;font-weight:500;\">#{text}</p></messageML>"
  waitFor 2000
  
module.exports = (robot) ->
  robot.hear /^\/(update|deploy) ([a-zA-Z]+,?(.*)) ([a-zA-Z]+) ?(.*)$/i, (msg) ->
    doSafe(msg, jenkinsParseParams)
    
  robot.hear /^\/last (.*)$/i, (msg) ->
    doSafe(msg, jenkinsLast)
    
  robot.hear /^\/version?$/i, (msg) ->
    doSafe(msg, jenkinsShowCurrentVersion)
    
  robot.hear /^\/set version (.*)$/i, (msg) ->
    doSafe(msg, jenkinsChangeCurrentVersion)
    
  robot.hear /^\/(H|h)elp$/i, (msg) ->
    doSafe(msg, jenkinsHelp)
    
  robot.hear /^\/(H|h)ello$/i, (msg) ->
    doSafe(msg, jenkinsHello)

  