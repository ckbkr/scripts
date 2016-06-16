#tch current directory (recursively) for file changes, and execute
# a command when a file or directory is created, modified or deleted.
#
# Written by: Senko Rasic <senko.rasic@dobarkod.hr>
#
# Requires Linux, bash and inotifywait (from inotify-tools package).
#
# To avoid executing the command multiple times when a sequence of
# events happen, the script waits one second after the change - if
# more changes happen, the timeout is extended by a second again.
#
# Installation:
#     chmod a+rx onchange.sh
#     sudo cp onchange.sh /usr/local/bin
#
# Example use - rsync local changes to the remote server:
#    
#    onchange.sh rsync -avt . host:/remote/dir
#
# Released to Public Domain. Use it as you like.
#
# rsync -vat webs/ ruby@daskekshaus.de:/home/ruby/webs
EVENTS="CREATE,CLOSE_WRITE,DELETE,MODIFY,MOVED_FROM,MOVED_TO"

#if [ -z "$1" ]; then
#    echo "Usage: $0 cmd ..."
#    exit -1;
#fi

rsync -va --delete ruby@daskekshaus.de:/home/ruby/webs .

inotifywait -e "$EVENTS" -m -r --format '%:e %f' . | (
    WAITING="";
    while true; do
        LINE="";
        read -t 1 LINE;
        if test -z "$LINE"; then
            if test ! -z "$WAITING"; then
                    echo "CHANGE";
                    WAITING="";
            fi;
        else
            WAITING=1;
        fi;
    done) | (
    while true; do
        read TMP;
        #echo "rsync -vat webs/ ruby@daskekshaus.de:/home/ruby/webs"
        rsync -vat --delete webs/app/ ruby@daskekshaus.de:/home/ruby/webs/app
        rsync -vat --delete webs/config/ ruby@daskekshaus.de:/home/ruby/webs/config
        rsync -vat --delete webs/lib/ ruby@daskekshaus.de:/home/ruby/webs/lib
        rsync -vat --delete webs/db/migrate/ ruby@daskekshaus.de:/home/ruby/webs/db/migrate

	#$@
    done
)
