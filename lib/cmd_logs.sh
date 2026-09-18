# zfpga logs -- list or clean the captured boot logs in $WS/logs.
#   zfpga logs                list logs (newest first) with size + date
#   zfpga logs clean          delete all logs
#   zfpga logs clean --keep N keep the N newest, delete the rest

cmd_logs() {
    local dir="$WS/logs"
    local action="list" keep=0
    while [ $# -gt 0 ]; do
        case $1 in
            list)   action=list; shift ;;
            clean)  action=clean; shift ;;
            --keep) keep=$2; shift 2 ;;
            *)      die "logs: unknown argument '$1'" ;;
        esac
    done
    [ "$keep" -eq 0 ] 2>/dev/null || [ "$keep" -ge 0 ] 2>/dev/null || die "logs: --keep needs a non-negative number"

    if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        info "no logs in $dir"; return 0
    fi

    # Newest first.
    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(ls -1t "$dir")

    if [ "$action" = list ]; then
        info "logs in $dir (newest first):"
        ( cd "$dir" && ls -lht "${files[@]}" | awk 'NR>0 {print "  " $5 "\t" $6" "$7" "$8 "\t" $9}' )
        info "${#files[@]} file(s). Clean with 'zfpga logs clean [--keep N]'."
        return 0
    fi

    # clean: keep the N newest, remove the rest.
    local removed=0 i=0
    for f in "${files[@]}"; do
        i=$((i+1))
        [ "$i" -le "$keep" ] && continue
        rm -f "$dir/$f" && removed=$((removed+1))
    done
    if [ "$keep" -gt 0 ]; then info "removed $removed log(s); kept $keep newest."
    else info "removed $removed log(s)."; fi
}
