#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra/cross_origin'
require 'sinatra/reloader'
require 'nanomsg'
require 'zipf'
require 'json'
require 'tilt/haml'
require 'uri'
require 'rack'
require_relative './derivation_to_json/derivation_to_json'
require_relative './phrase2_extraction/phrase2_extraction'

# #############################################################################
# Load configuration file and setup global variables
# #############################################################################
NOLOO = nil                          # added later, warning
OLM = nil                            # added later, warning
$olm_pipe = nil
require_relative "#{ARGV[0]}"        # load configuration for this session
$lock                    = false     # lock if currently learning/translating
$last_reply              = nil       # cache last reply
$last_processed_postedit = ""        # to show to the user
$confirmed               = true      # client received translation?
$new_rules               = []        # corrected OOVs and newly extracted rules
$known_rules             = []        # known rules
if !FileTest.exist? LOCK_FILE        # locked?
  $db  = {}                          # data file (JSON format)
  $env = {}                          # environment variables (socket connections to daemons)
end
$status                  = "Idle"    # current server status
$pregenerated_grammars   = true      # FIXME config
$oov_corrected           = {}
$oov_corrected.default   = false

# #############################################################################
# Daemons
# #############################################################################
DIR="/srv/postedit"
$daemons = {
  :tokenizer        => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a tokenize   -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :tokenizer_src    => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a tokenize   -S '__ADDR__' -e #{EXTERNAL} -l #{SOURCE_LANG}",
  :detokenizer      => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a detokenize -S '__ADDR__' -e #{EXTERNAL} -l #{TARGET_LANG}",
  :detokenizer_src  => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a detokenize -S '__ADDR__' -e #{EXTERNAL} -l #{SOURCE_LANG}",
  :truecaser        => "#{DIR}/lfpe/util/nanomsg_wrapper.rb -a truecase   -S '__ADDR__' -e #{EXTERNAL} -t #{SESSION_DIR}/truecase.model",
  :dtrain           => "#{CDEC}/training/dtrain/dtrain_net_interface -c #{SESSION_DIR}/dtrain.ini -d #{WORK_DIR}/dtrain.debug.json -o #{WORK_DIR}/weights -a '__ADDR__' -E -R",
  #:extractor        => "python -m cdec.sa.extract -c #{SESSION_DIR}/extract.ini --online -u -S '__ADDR__'",
  #:aligner_fwd      => "#{CDEC}/word-aligner/net_fa -f #{SESSION_DIR}/forward.params  -m #{FWD_MEAN_SRCLEN_MULT}  -T #{FWD_TENSION}  --sock_url '__ADDR__'",
  #:aligner_back     => "#{CDEC}/word-aligner/net_fa -f #{SESSION_DIR}/backward.params -m #{BACK_MEAN_SRCLEN_MULT} -T #{BACK_TENSION} --sock_url '__ADDR__'",
  #:atools           => "#{CDEC}/utils/atools_net -c grow-diag-final-and -S '__ADDR__'"
}

# #############################################################################
# Set-up Sinatra
# #############################################################################
set :server,            'thin'
set :bind,              SERVER_IP
set :port,              WEB_PORT
set :allow_origin,      :any
set :allow_methods,     [:get, :post]
set :allow_credentials, true
set :max_age,           "1728000"
set :expose_headers,    ['Content-Type']
set :public_folder,     File.dirname(__FILE__) + '/static'

Rack::Utils.key_space_limit = 68719476736

# #############################################################################
# Helper functions
# #############################################################################
def logmsg name, msg
  STDERR.write "[#{name}] #{msg}\n"
end

def start_daemon cmd, name, addr
  logmsg :server, "starting #{name} daemon"
  cmd.gsub! '__ADDR__', addr
  pid = spawn(cmd)
  Process.detach pid
  logmsg :server, "#{name} detached"
  sock = NanoMsg::PairSocket.new
  sock.connect addr
  logmsg :server, "< got #{sock.recv} from #{name}"

  return sock, pid
end

def stop_all_daemons
  $status = "Shutting down"                                            # status
  logmsg :server, "shutting down all daemons"
  $env.each { |name,p|
    p[:socket].send "shutdown"                   # every daemon shuts down
                                                 # after receiving this keyword
    logmsg :server, "< #{name} is #{p[:socket].recv}"
  }

  $status = "Ready to shutdown"                                        # status
end

def update_database reset=false
  $status = "Updating database"                                        # status
  if !reset
    $db['progress'] += 1
  else
    $db['progress'] = 0
  end
  j = JSON.generate $db
  f = WriteFile.new DB_FILE
  f.write j.to_s
  f.close

  $status = "Updated database"                                         # status
end

def init
  $status = "Initialization"                                           # status
  $db = JSON.parse ReadFile.read DB_FILE                  # data from JSON file
                                                            # working directory
  `mkdir -p #{WORK_DIR}/`
  `mkdir #{WORK_DIR}/g`

  if OLM
    `mkfifo #{WORK_DIR}/refp`
  end

                                             # setup environment, start daemons
  port = BEGIN_PORT_RANGE
  $daemons.each { |name,cmd|
    logmsg :server, "starting #{name} daemon"
    sock, pid = start_daemon cmd, name, "tcp://127.0.0.1:#{port}"
    $env[name] = { :socket => sock, :pid => pid }
    port += 1
    logmsg :server, "starting #{name} daemon done"
  }

  if OLM
    logmsg :server, "writing to OLM pipe"
    $olm_pipe = File.new "#{WORK_DIR}/refp", "w"
    $olm_pipe.write " \n"
    $olm_pipe.flush
    logmsg :server, "writing to OLM pipe, done!"
  end

  send_recv :truecaser, "lOaD iT"

  #if OLM
  #  $olm_pipe = File.new "#{WORK_DIR}/refp", "w"
  #end
                                                                   #  lock file
  `touch #{LOCK_FILE}`
  $status = "Initialized"                                              # status
end

def send_recv daemon, msg                            # simple pair communcation
  socket = $env[daemon][:socket]                     # query -> answer
  logmsg daemon, "> sending message: '#{msg}'"
  socket.send msg
  logmsg daemon, "waiting ..."
  ans = socket.recv.force_encoding("UTF-8").strip
  logmsg daemon, "< received answer: '#{ans}'"

  return ans
end

def clean_str s
  s.gsub! "[", "SQUARED_BRACKET_OPEN"
  s.gsub! "]", "SQUARED_BRACKET_CLOSE"
  s.gsub! "|", "PIPE"

  return s
end

# #############################################################################
# Run init() [just once]
# #############################################################################
init if !FileTest.exist?(LOCK_FILE)

# #############################################################################
# Routes
# #############################################################################
get '/' do
  cross_origin                           # enable Cross-Origin Resource Sharing

  return ""                                                            # return
end

post '/next' do
  cross_origin

  $status = "Received request"                                         # status
  reply = request.body.read
  Thread.new { process_next reply }
end

def process_next reply
  $status = "Processing request"                                       # status
  data = JSON.parse(URI.decode(reply))
  if $lock
    $status = "Locked"                                                 # status
    return
  end
  $lock = true                                                           # lock
  if !data['name'] || data['name'] == ""
    $status = "Error: Name not given."
    return
  end
  if data['key'] != SESSION_KEY
    $status =  "Error: Key mismatch (#{data['key']}, #{SESSION_KEY})"
    return
  end
  if data["OOV"]                                              # OOV corrections
    $status = "Processing OOV corrections"
    logmsg :server, "received OOV corrections"                         # status
    logmsg :server, "#{data.to_s}"
    #grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
    grammar = "#{SESSION_DIR}/g/grammar.#{$db['progress']}"
    src, tgt = splitpipe(data["correct"]) # format:src1\tsrc2\tsrc..|||tgt1\t..
    tgt = clean_str tgt
    src = src.split("\t").map { |i| URI.decode(i).strip }
    tgt = tgt.split("\t").map { |i| URI.decode(i).strip }
    $status = "Adding rules to handle OOVs"                            # status
    src.each_with_index { |s,i|
      next if s==''||tgt[i]==''
      as = ""
      tgt[i].split.each_index { |k| as += " 0-#{k}" }
      r = "[X] ||| #{s} ||| #{tgt[i]} ||| OOVFix=1 ||| #{as}"
      $new_rules << r
    }
    $confirmed = true
    $oov_corrected[$db['progress']] = true
  end
# received post-edit -> update models
# 0. save raw post-edit
# 1. tokenize [for each phrase]
# 2. truecase [for each phrase]
# 2.5 extract new rules
# 3. save processed post-edit
# 4. update weights
# 5. update grammar extractor
# 5a. forward alignment
# 5b. backward alignment
# 5c. symmetrize alignment
# 5d. actual update
# 5e. update LM
# 6. update database
  if data["EDIT"]
    $status = "Processing post-edit"                                   # status
    logmsg :server, "received post-edit"
                                                        # 0. save raw post-edit
    source = data["source_value"]
    post_edit = ''
    if data["type"] == 'g'                                # graphical interface
      post_edit = data["target"].join(" ")
      e = []
      logmsg :server, "post-edit before processing: '#{post_edit}'"
      $status = "Tokenizing and truecasing post-edited phrases"        # status
      data["target"].each_with_index { |i,j|
                                                                # [1.] tokenize
        _ = clean_str send_recv(:tokenizer, URI.decode(i))
        prev = _[0]                                       # use received casing
                                                                # [2.] truecase
        _ = send_recv :truecaser, _
        _[0] = prev if j>0
        e << _
      }
      logmsg :server, "post-edit after processing: '#{e.join " "}'"
      f = []
      data["source_raw"].each { |i| f << URI.decode(i) }

      # no loo rules
      no_loo_known_rules = []
      no_loo_new_rules = []

      if !NOGRAMMAR
                                                        # 2.5 new rule extraction
        $status = "Extracting rules from post edit"                      # status
        #grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
        grammar = "#{SESSION_DIR}/g/grammar.#{$db['progress']}"
        current_grammar_ids = {}
        ReadFile.readlines_strip(grammar).each { |r|
          s = splitpipe(r.to_s)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
          current_grammar_ids[s] = true
        }
        # no loo rules
        no_loo_known_rules = []
        no_loo_new_rules = []
        if NOLOO
          tmp_rules = []
          logmsg :server, "rule diff: #{data['rule_diff'].to_s}"
          data["rule_diff"].each_key { |k|
            x = k.split(",").map{|i|i.to_i}.sort
            tgt_a = data["rule_diff"][k]["tgt_a"]
            tgt_first,src,tgt = splitpipe data["rule_diff"][k]
            tgt_first = tgt_first.lstrip.strip
            src = src.lstrip.strip
            tgt = tgt.lstrip.strip
            prev = tgt[0]
            logmsg :server, "tgt_first #{tgt_first}"
            tgt = send_recv :truecaser, tgt
            tgt[0] = prev if tgt_first=="false"
            if x.first == 0
              src[0] = data["source_value"][0]
            end
            tmp_rules << [src, tgt]
          }
          tmp_rules_new = tmp_rules.reject { |r|
              current_grammar_ids.has_key? r.join(' ||| ')
          }
          tmp_rules_known = tmp_rules - tmp_rules_new
          tmp_rules_known.each { |i|
            no_loo_known_rules << "[X] ||| #{i[0]} ||| #{i[1]} ||| KnownRule=1 ||| 0-0"
          }
          tmp_rules_new.each { |i|
            a = []
            i[0].strip.lstrip.split.each_with_index { |s,ii|
              i[1].strip.lstrip.split.each_with_index { |t,j|
                if !s.match /\[X,\d+\]/ and !t.match /\[X,\d+\]/
                  a << "#{ii}-#{j}"
                end
              }
            }
            no_loo_new_rules << "[X] ||| #{i[0]} ||| #{i[1]} ||| NewRule=1 ||| #{a.join ' '}"
          }
        end
        # regular
        new_rules = PhrasePhraseExtraction.extract_rules f, e, data["align"], true
        new_rules_ids = {}
        $new_rules.each { |r|
          s = splitpipe(r.to_s)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
          new_rules_ids[s] = true
        }
        new_rules = new_rules.map { |r| r.as_trule_string }
        _ = new_rules.dup
        logmsg :server, "# rules before filtering #{new_rules.size}"
        new_rules.reject! { |rs|
          s = splitpipe(rs)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
          current_grammar_ids.has_key?(s) || new_rules_ids.has_key?(s)
        }
        $new_rules += new_rules
        $new_rules += no_loo_new_rules
        $new_rules.uniq! { |rs|
          splitpipe(rs)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
        }
        f = WriteFile.new "#{WORK_DIR}/#{$db['progress']}.new_rules"
        f.write new_rules.join "\n"
        f.close
        logmsg :server, "# rules after filtering #{new_rules.size}"
        add_known_rules = _-new_rules
        add_known_rules += no_loo_known_rules
        add_known_rules.reject! { |rs|
          s = splitpipe(rs)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
          new_rules_ids.has_key?(s)
        }
        f = WriteFile.new "#{WORK_DIR}/#{$db['progress']}.known_rules"
        f.write add_known_rules.join "\n"
        f.close
        $known_rules += add_known_rules
        $known_rules.uniq! { |rs|
          splitpipe(rs)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
        }
        add_known_rules.each { |r| logmsg :server, "known_rule: '#{r}'" }
      end
    else                                                       # text interface
      post_edit = data["post_edit"]
    end
    $status  = "Processing post-edit ..."                              # status
    post_edit.strip!
    post_edit.lstrip!
    post_edit = clean_str post_edit
                                                                      # fill db
    $db['feedback']           << reply
    $db['post_edits_raw']     << post_edit
    $db['svg']                << data['svg']
    $db['original_svg']       << data['original_svg']
    $db['durations']          << data['duration'].to_f
    $db['durations_rating']   << data['duration_rating'].to_f
    $db['count_click']        << data['count_click'].to_i
    $db['count_kbd']          << data['count_kbd'].to_i
    $db['post_edits_display'] << send_recv(:detokenizer, post_edit)
    $db['ratings']            << data['rating'].to_f
    $last_processed_postedit = $db['post_edits_display'].last
    # 1. tokenize
      $status = "Tokenizing post-edit"                                 # status
      logmsg :server, "tokenizing post-edit"
      post_edit = send_recv :tokenizer, post_edit
    # 2. truecase
      $status = "Truecasing post-edit"                                 # status
      logmsg :server, "truecasing post-edit"
      post_edit = send_recv :truecaser, post_edit
    # 3. save processed post-edits
      $status = "saving processed post-edit"                           # status
      logmsg :db, "saving processed post-edit"
      $db['post_edits'] << post_edit.strip
    nochange = false
    if data['nochange']
      logmsg :server, "no change -> no update!"
      nochange = true
    end
    if !NOLEARN && !NOMT && !nochange
      $status = "Updating models"                                      # status
      logmsg :server, "updating ..."
                             # 4. update weights
                             # N.b.: this uses unaltered grammar [no new rules]
      #grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
      grammar = "#{SESSION_DIR}/g/grammar.#{$db['progress']}"
      annotated_source = "<seg grammar=\"#{grammar}\"> #{source} </seg>"
      $status = "Learning from post-edit"                              # status
      if NOLOO
        `cp #{grammar} #{grammar}.pass0`
        match = {}
        no_loo_known_rules.each { |r|
          _,src,tgt,_,_ = splitpipe r
          match["#{src.strip.lstrip} ||| #{tgt.strip.lstrip}".hash] = true
        }
        all_rules = ReadFile.readlines_strip grammar
        all_rules.each_with_index { |r,j|
          nt,src,tgt,f,a = splitpipe(r).map { |i| i.strip.lstrip }
          if match["#{src} ||| #{tgt}".hash]
            ar = "#{nt} ||| #{src} ||| #{tgt} ||| #{f} KnownRule=1 ||| #{a}"
            logmsg :server, "replacing rule '#{r}' with '#{ar}'"
            all_rules[j] = ar
          end
        }
        if no_loo_new_rules.size > 0
          all_rules += no_loo_new_rules
        end
        f = WriteFile.new(grammar)
        f.write(all_rules.join("\n")+"\n")
        f.close
        logmsg :server, "adding rules and re-translate"
        if OLM # again ..
          $status = "Updating language model"
          logmsg :server, "fake updating lm"
          $olm_pipe.write " \n"
          $olm_pipe.flush
        end
        `cp #{WORK_DIR}/dtrain.debug.json \
          #{WORK_DIR}/#{$db['progress']}.dtrain.debug.json.pass0`
        send_recv :dtrain, "act:translate_learn ||| #{annotated_source} ||| #{post_edit}"
        `cp #{WORK_DIR}/dtrain.debug.json \
          #{WORK_DIR}/#{$db['progress']}.dtrain.debug.json.pass1`
      else
        logmsg :server, "no NOLOO"
        send_recv :dtrain, "act:learn ||| #{annotated_source} ||| #{post_edit}"
        `cp #{WORK_DIR}/dtrain.debug.json \
          #{WORK_DIR}/#{$db['progress']}.dtrain.debug.json.pass0`
      end
                                                  # 5. update grammar extractor
      if !$pregenerated_grammars
                                                    # 5a. get forward alignment
        source_lc = source.downcase
        post_edit_lc = post_edit.downcase
        $status = "Aligning post-edit"                                 # status
        a_fwd = send_recv :aligner_fwd, "#{source_lc} ||| #{post_edit_lc}"
                                                   # 5b. get backward alignment
        a_back = send_recv :aligner_back, "#{source_lc} ||| #{post_edit_lc}"
                                                       # 5c. symmetrize alignment
        a = send_recv :atools, "#{a_fwd} ||| #{a_back}"
                                                          # 5d actual extractor
        $status = "Updating grammar extractor"                         # status
        msg = "default_context ||| #{source} ||| #{post_edit} ||| #{a}"
        send_recv :extractor, msg
      end
                                                           # 5e update LM
      if OLM
        $status = "Updating language model"
        logmsg :server, "updating lm"
        #`echo "#{post_edit}" >> #{WORK_DIR}/refp`
        $olm_pipe.write "#{post_edit}\n"
        $olm_pipe.flush
      end
                                                           # 6. update database
      $db['updated'] << true
    else
      `cp #{WORK_DIR}/dtrain.debug.json \
        #{WORK_DIR}/#{$db['progress']}.dtrain.debug.json.nolearn`
      $db['updated'] << false
      if OLM
        $status = "Updating language model"
        logmsg :server, "fake updating lm"
        $olm_pipe.write " \n"
        $olm_pipe.flush
      end
    end
    logmsg :db, "updating database"
    update_database
  end
  $status = "Getting next data to translate"                           # status
  source     = $db['source_segments'][$db['progress']]
  raw_source = $db['raw_source_segments'][$db['progress']]
  if !source                                                    # input is done
    logmsg :server, "end of input, sending 'fin'"
    $lock = false
    $status = "Ready"                                                  # status
    $last_reply = {'fin'=>true,
      'processed_postedit'=>$last_processed_postedit
    }.to_json
    return                                                             # return
  elsif !$confirmed \
    || ($confirmed && $last_reply && $last_reply!="" \
        && !data["EDIT"] && !$last_reply.to_json["oovs"])     # send last reply
    logmsg :server, "locked, re-sending last reply"
    logmsg :server, "last_reply: '#{$last_reply}'"
    $lock = false
    $status = "Ready"                                                  # status
    return
  else
# translate next sentence
# 0. no mt?
# 1. generate grammar
# - known rules
# - additional rules
# 2. check for OOV
# 3. translate
# 4. detokenize
# 5. reply

    source = source.strip.lstrip
    raw_source = raw_source.strip.lstrip

    if NOMT                                                         # 0. no mt?
      $lock = false
      logmsg :server, "no mt"
      obj = Hash.new
      obj["progress"]   = $db["progress"]
      obj["source"]     = source
      obj["raw_source"] = raw_source
      obj["processed_postedit"] = $last_processed_postedit
      $last_reply = obj.to_json
      $status = "Ready"                                                # status
      return
    end

                                     # 1. generate grammar for current sentence
    $status = "Generating grammar"                                     # status
    logmsg :server, "generating grammar for segment ##{$db['progress']}"
    grammar = "#{WORK_DIR}/g/#{$db['progress']}.grammar"
    if !$pregenerated_grammars
      if !File.exist? grammar      # grammar already generated if there were OOVs
        send_recv :extractor, "default_context ||| #{source} ||| #{grammar}"
      end
    else
      grammar = "#{SESSION_DIR}/g/grammar.#{$db['progress']}"
    end
                                                                # - known rules
    logmsg :server, "annotating known rules"
    logmsg :server, "grammar file: #{grammar}"
    $status = "Adding rules to the grammar"                            # status
    match = {}
    $known_rules.each { |r|
      _,src,tgt,_,_ = splitpipe r
      match["#{src.strip.lstrip} ||| #{tgt.strip.lstrip}".hash] = true
    }
    all_rules = ReadFile.readlines_strip grammar
    all_rules.each_with_index { |r,j|
      nt,src,tgt,f,a = splitpipe(r).map { |i| i.strip.lstrip }
      if match["#{src} ||| #{tgt}".hash]
        ar = "#{nt} ||| #{src} ||| #{tgt} ||| #{f} KnownRule=1 ||| #{a}"
        logmsg :server, "replacing rule '#{r}' with '#{ar}'"
        all_rules[j] = ar
      end
    }
                                                           # - additional rules
    if $new_rules.size > 0
      all_rules += $new_rules
    end
    f = WriteFile.new(grammar)
    f.write(all_rules.join("\n")+"\n")
    f.close
    #$new_rules.each { |rule|
    # logmsg :server, "adding rule '#{rule}' to grammar '#{grammar}'"
    #  s = splitpipe(rule)[1..2].map{|i|i.strip.lstrip}.join(" ||| ")
    #  `echo "#{rule}" >> #{grammar}`
    #}
                                                            # 2. check for OOVs
    if !$oov_corrected[$db['progress']]
    $status = "Checking for OOVs"                                      # status
    logmsg :server, "checking for oovs"
    src_r = ReadFile.readlines(grammar).map {
      |l| splitpipe(l)[1].strip.split
    }.flatten.uniq
    oovs = []
    logmsg :server, "OOVs in '#{source}'"
    logmsg :server, "coverage: #{src_r.to_s}"
    source.split.each { |token|
      if !src_r.include? token
        oovs << token
        logmsg :server, "OOV token: '#{token}'"
      end
    }
    oovs.uniq!
    logmsg :server, "have OOVs: '#{oovs.to_s}'"
    if oovs.size > 0                                                     # OOVs
      $status = "Asking for feedback on OOVs"                          # status
      obj = Hash.new
      obj["oovs"]      = oovs
      obj["progress"]  = $db['progress']
      raw_source_annot = "#{raw_source}"
      oovs.each { |o|
        raw_source_annot.gsub! "#{o}", "***#{o}###"
      }
      obj["raw_source"] = raw_source_annot
      obj["processed_postedit"] = $last_processed_postedit
      $last_reply = obj.to_json
      logmsg :server, "OOV reply: '#{$last_reply}'"
      $lock = false
      $confirmed = false
      $status = "Ready"                                                # status
      return                                                           # return
    end
    end
    # 3. translation
    $status = "Translating"                                            # status
    msg = "act:translate ||| <seg grammar=\"#{grammar}\"> #{source} </seg>"
    derivation_str = send_recv :dtrain, msg
    obj_str = DerivationToJson.proc_deriv derivation_str
    obj = JSON.parse obj_str
    obj["transl"] = obj["target_groups"].join " "
    # 4. detokenizer
    $status = "Processing raw translation"                             # status
    obj["transl_detok"] = send_recv(:detokenizer, obj["transl"]).strip
    obj["target_groups"].each_index { |j|
      prev = obj["target_groups"][j][0]
      obj["target_groups"][j] = send_recv(:detokenizer, obj["target_groups"][j]).strip
      obj["target_groups"][j][0]=prev if j > 0
    }
    obj["source"]     = source
    obj["progress"]   = $db['progress']
    obj["raw_source"] = raw_source
    w_idx = 0
    obj["source_groups_raw"] = []
    obj["source_groups"].each { |i|
      obj["source_groups_raw"] << String.new(i)
    }
    obj["source_groups_raw"][0][0] = source[0]
    obj["source_groups"][0][0] = obj["source_groups"][0][0].upcase
    obj["source_groups"].each_with_index { |i,j|
      prev = obj["source_groups"][j][0]
      obj["source_groups"][j] = send_recv(:detokenizer_src, obj["source_groups"][j]).strip
      obj["source_groups"][j][0]=prev if j > 0
    }
                                                                         # save
    $db["derivations"]      << derivation_str
    $db["derivations_proc"] << obj_str
    $db["mt_raw"]           << obj["transl"]
    $db["mt"]               << obj["transl_detok"]
    obj["processed_postedit"] = $last_processed_postedit
                                                                     # 5. reply
    $last_reply = obj.to_json
    $lock = false
    $confirmed = false
    logmsg :server, "response: '#{$last_reply}'"
    $status = "Ready"                                                  # status
    return                                                             # return
  end
end

get '/debug' do                                                    # debug view
  data = {}
  s = File.binread(DB_FILE).encode('UTF-8', 'UTF-8', :invalid => :replace, :replace => "__INVALID__")
  data = JSON.parse s
  if data["durations"].size == 0
    data["durations"] << -1
  end
  if data["durations_rating"].size == 0
    data["durations_rating"] << -1
  end

  fn = "#{WORK_DIR}/#{$db["progress"]-1}.dtrain.debug.json.pass"
  pass = 0
  if File.exist? fn+"1"
    fn += "1"
    pass = 1
  else
    fn += "0"
    pass = 0
  end
  pairwise_ranking_data                     = {}
  pairwise_ranking_data["kbest"]            = []
  pairwise_ranking_data["weights_before"]   = {}
  pairwise_ranking_data["weights_after"]    = {}
  pairwise_ranking_data["best_match_score"] = 0
  if File.exist? fn
    s = File.binread(fn).encode('UTF-8', 'UTF-8', :invalid => :replace, :replace => "__INVALID__").force_encoding("utf-8")
    begin
      pairwise_ranking_data = JSON.parse s
    rescue
      logmsg :server, s.encoding
    end
  end

  admin = false
  if params[:admin]
    admin = true
  end

  haml :debug, :locals => { :data => data,
                            :pairwise_ranking_data => pairwise_ranking_data, \
                            :progress => $db["progress"]-1,
                            :pass => pass,
                            :new_rules => $new_rules, \
                            :known_rules => $known_rules, \
                            :session_key => SESSION_KEY, \
                            :admin => admin }
end

get '/new_rules'     do                                       # new/known rules
  return $new_rules.join "<br />"
end
get '/known_rules' do
  return $known_rules.join "<br />"
end

get '/fetch' do                                                    # fetch next
  cross_origin
  return "Locked" if $locked
  return $last_reply
end

get '/fetch_processed_postedit/:i' do                     # processed post-edit
  cross_origin
  i = params[:i].to_i
  return $db['post_edits_display'][i]
end

get '/progress' do                                        # processed post-edit
  cross_origin
  return $db['progress']
end

get '/status' do                                                 # check status
  cross_origin
  logmsg :server, "status: #{$status}"
  return "Locked" if $locked
  return $status
end

get '/status_debug' do                                                 # check status
  cross_origin
  logmsg :server, "status: #{$status}"
  return "[##{$db["progress"]}] Locked" if $locked
  return "[##{$db["progress"]}] #{$status}"
end

get '/confirm' do                        # client confirms received translation
  cross_origin
  $confirmed = true
  logmsg :server, "confirmed = #{$confirmed}"

  return "#{$confirmed}"
end

get '/set_weights/:name/:rate' do                                 # set weights
  name = params[:name].gsub " ", "_"
  rate = params[:rate].to_f
  logmsg :server, "set weight for '#{name}' to: #{rate}"
  return "locked" if $lock
  msg = send_recv :dtrain, "set_weights #{name} #{rate}"

  return msg
end

get '/set_learning_rates/:name/:rate' do                   # set learning rates
  name = params[:name].gsub " ", "_"
  rate = params[:rate].to_f
  logmsg :server, "set learning rate for '#{name}' to: #{rate}"
  return "locked" if $lock
  msg = send_recv :dtrain, "set_learning_rates #{name} #{rate}"

  return msg
end

get '/get_weight/:name' do
  name = params[:name].gsub " ", "_"
  logmsg :server, "getting weight for '#{name}'"
  return "locked" if $lock
  msg = send_recv :dtrain, "get_weight #{name}"

  return msg
end

get '/get_rate/:name' do
  name = params[:name].gsub " ", "_"
  logmsg :server, "getting rate for '#{name}'"
  return "locked" if $lock
  msg = send_recv :dtrain, "get_rate #{name}"

  return msg
end

get '/reset_weights' do                                         # reset weights
  logmsg :server, "reset weights"
  return "locked" if $lock
  send_recv :dtrain, "reset_weights"

  return "reset weights: done"
end

get '/reset_learning_rates' do                           # reset learning rates
  logmsg :server, "reset learning rates"
  return "locked" if $lock
  send_recv :dtrain, "reset_learning_rates"

  return "reset learning rates: done"
end

get '/reset_progress' do                                # reset current session
  return "locked" if $lock
  $db = JSON.parse ReadFile.read DB_FILE
  $db['post_edits'].clear
  $db['post_edits_raw'].clear
  $db['post_edits_display'].clear
  $db['mt'].clear
  $db['mt_raw'].clear
  $db['updated'].clear
  $db['durations'].clear
  $db['durations_rating'].clear
  $db['derivations'].clear
  $db['derivations_proc'].clear
  $db['svg'].clear
  $db['original_svg'].clear
  $db['feedback'].clear
  $db['progress'] = -1
  $db['count_kbd'].clear
  $db['count_click'].clear
  $db['ratings'].clear
  update_database true
  $confirmed = true
  $last_reply = nil
  $oov_corrected.clear

  return "progress reset: done"
end

get '/reset_extractor' do                             # reset grammar extractor
  logmsg :server, "reset extractor"
  return "locked" if $lock
  send_recv :extractor, "default_context ||| drop"

  return "reset extractor: done"
end

get '/reset_grammars' do                               # reset grammar extractor
  logmsg :server, "reset grammars"
  return "locked" if $lock
  `cp #{SESSION_DIR}/g/original/* #{SESSION_DIR}/g/`
  $last_reply = nil

  return "reset grammars: done"
end

get '/reset_new_rules' do                               # removed learned rules
  $new_rules.clear
  $known_rules.clear
  `rm #{WORK_DIR}/*.*_rules`
  `rm #{WORK_DIR}/g/*`
  $last_reply = nil

  return "reset new rules: done"
end

get '/shutdown' do                          # stop daemons and shut down server
  logmsg :server, "shutting down daemons"
  stop_all_daemons

  return "stopped all daemons, ready to shutdown"
end

get '/summary' do
  logmsg :server, "showing summary"

  data = JSON.parse ReadFile.read(DB_FILE).force_encoding("UTF-8")

  ter_scores = []
  data["post_edits"].each_with_index { |pe,j|
    f = Tempfile.new "lfpe-summary-pe"
    g = Tempfile.new "lfpe-summary-ref"
    f.write pe+"\n"
    g.write data["references"][j]+"\n"
    f.close
    g.close
    ter_scores << [1.0, (`#{CDEC}/mteval/fast_score -i #{f.path} -r #{g.path} -m ter 2>/dev/null`.to_f).round(2)].min
    f.unlink
    g.unlink
  }

  hter_scores = []
  data["post_edits"].each_with_index { |pe,j|
    f = Tempfile.new "lfpe-summary-mt"
    g = Tempfile.new "lfpe-summary-pe"
    f.write data["mt_raw"][j]+"\n"
    g.write pe+"\n"
    f.close
    g.close
    hter_scores << [1.0, (`#{CDEC}/mteval/fast_score -i #{f.path} -r #{g.path} -m ter 2>/dev/null`.to_f).round(2)].min
    f.unlink
    g.unlink
  }

  haml :summary, :locals => { :session_key => SESSION_KEY,
                              :data => data,
                              :ter_scores => ter_scores,
                              :bleu_scores => bleu_scores,
                              :hter_scores => hter_scores }

end

