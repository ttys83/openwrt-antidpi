case $- in
    *i*) ;;
    *) return ;;
esac

case ${TERM:-dumb} in
    dumb|'') PS1='[\u@\h] \w \$ ' ;;
    *) PS1='\[\e[36m\][\u@\h]\[\e[0m\] \[\e[34m\]\w\[\e[0m\] \$ ' ;;
esac
export PS1
