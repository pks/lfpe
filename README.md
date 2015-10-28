# lfpe

# setup
## nanomsg lib
    export LD_LIBRARY_PATH=/fast_scratch/simianer/lfpe/lib/nanomsg-0.5-beta/lib

## ruby
    $(pwd)/lib/ruby/gems/nanomsg-0.4.0/ext/extconf.rb
    gem install nanomsg -i $(pwd)/lib/ruby
    export GEM_PATH=/fast_scratch/simianer/lfpe/lib/ruby/:$GEM_PATH

## iptables
    -A INPUT -i eth0 -p tcp -m multiport --dports 50000:50100 -j ACCEPT

## apache
    /etc/apache2/conf.d/lfpe.conf

## python
    export PYTHONPATH=/fast_scratch/simianer/lfpe/lib/python:$PYTHONPATH

