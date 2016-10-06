_ = require "lodash"
path = require 'path'
hare = require 'hare'
gitlab = require 'node-gitlab'
async = require 'async'
YAML = require 'json2yaml'
amqp = require 'amqp' # via hare !
figlet = require 'figlet'

workerName = path.basename __filename, '.coffee'

AMQP_URL = process.env.AMQP_URL or 'amqp://127.0.0.1:5672'
GITLAB_URL = process.env.GITLAB_URL or 'http://localhost:10080/api/v3'
GITLAB_TOKEN = process.env.GITLAB_TOKEN

unless GITLAB_TOKEN
  console.error "no env GITLAB_TOKEN set. aborting"
  process.exit 1

console.info "
  [#{workerName}] starting, pid:#{process.pid}|
  #{AMQP_URL}| #{GITLAB_URL}| #{GITLAB_TOKEN}
  "

# input
conn = amqp.createConnection {url: AMQP_URL},
  defaultExchangeName: ''
  reconnect: true
  reconnectBackoffStrategy: 'linear'
  reconnectExponentialLimit: 120000
  reconnectBackoffTime: 1000

conn.on 'error', (err) ->
  console.error "RABBIT Connection ERR;"
  console.error YAML.stringify err

conn.on 'close', (hadError) ->
  console.error "RABBIT CLOSED! ", "(errors)" if hadError

conn.on 'timeout',  ->
  console.error "RABBIT TIMEOUT"

broker = hare conn
brokerLogExch = broker.pubSub "gitlab-events"
updatesQ = broker.workerQueue "#{workerName}s"

# output
gClient = gitlab.create
  api: GITLAB_URL
  privateToken: GITLAB_TOKEN

# glue
worker = (msg, headers, deliveryInfo, cb) ->
  console.log "msg", msg

  
  cb()

# init
async.parallel [
  (done) ->
    # FIXME wait a 'while'
    gClient.projects.list {}, done
  (done) ->
    conn.on 'ready', done
  ], (err,res) ->
    if err
      console.error "ABORTING. IO connect test ERR:"
      console.error (YAML.stringify err)
      process.exit 1
    else
      [projects,pubEv] = res
      projects_ = _.map projects, (p) -> { id:p.id, name:p.name }
      
      console.log ( figlet.textSync workerName,
        horizontalLayout: 'default'
        verticalLayout: 'default'
      )

      console.log projects_
      updatesQ.subscribe worker




