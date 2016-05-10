# Learning from post-edits
Post-editing interface for learning from post-edited machine translations.

# Setup

`
    export BASE_DIR=/srv/postedit
`

## nanomsg lib
`
    export LD_LIBRARY_PATH=$BASE_DIR/lib/nanomsg-0.5-beta/lib
`

## ruby
`
    [see $BASE_DIR/lib/ruby/gems/nanomsg-0.4.0/ext/extconf.rb]
    gem install nanomsg -i $BSAE_DIR/lib/ruby
    export GEM_PATH=$BASE_DIR/lib/ruby/:$GEM_PATH
`

## iptables
`
    iptables -A INPUT -i eth0 -p tcp -m multiport --dports 50000:50100 -j ACCEPT
`

## apache
`
    ln -s /etc/apache2/sites-available/lfpe /etc/apache2/sites-enabled/020-lfpe
`

## python
`
    export PYTHONPATH=$BASE_DIR/lib/python:$PYTHONPATH
`

