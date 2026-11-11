-- ZoomMirror: copy Zoom transcripts from ~/Documents/Zoom (the primary, where Zoom saves them) to ~/cos/zoom.
-- Scheduled jobs run under launchd, which macOS keeps out of ~/Documents (TCC). This small app is the one thing
-- that reads ~/Documents/Zoom, under its own Documents permission. It copies text only (.txt .md .vtt), never
-- deletes, and never touches the primary. launchd (com.cos.zoommirror) opens it when the folder changes, plus
-- 11:30 and 13:30 as a catch-up. It also copies the BOARD agent's handoff
-- (~/Documents/Data-Org-Repos/data-org-agent-handoff.md) to ~/cos/handbook/board-handoff.md, for STEWARD's jobs.
-- Built by install.sh from the kit; rebuilt only when this file changes, so the grant stays.
on run
	set h to POSIX path of (path to home folder)
	set src to quoted form of (h & "Documents/Zoom/")
	set dst to quoted form of (h & "cos/zoom/")
	set logf to quoted form of (h & "cos/state/zoom-mirror.log")
	try
		do shell script "/bin/mkdir -p " & dst & " && out=$(/usr/bin/rsync -a -i --include='*/' --include='*.txt' --include='*.md' --include='*.vtt' --exclude='*' --prune-empty-dirs " & src & " " & dst & " 2>&1); rc=$?; if [ $rc -ne 0 ]; then /bin/echo \"$(/bin/date +%FT%T) FAILED rc=$rc $out\" >> " & logf & "; else n=$(/bin/echo \"$out\" | /usr/bin/grep -c '^>f'); [ \"$n\" -gt 0 ] && /bin/echo \"$(/bin/date +%FT%T) copied $n\" >> " & logf & "; fi; exit 0"
		set hsrc to h & "Documents/Data-Org-Repos/data-org-agent-handoff.md"
		set hdst to h & "cos/handbook/board-handoff.md"
		do shell script "if [ -f " & quoted form of hsrc & " ]; then out=$(/usr/bin/rsync -a -i " & quoted form of hsrc & " " & quoted form of hdst & " 2>&1) || /bin/echo \"$(/bin/date +%FT%T) FAILED handoff $out\" >> " & logf & "; /bin/echo \"$out\" | /usr/bin/grep -q '^>f' && /bin/echo \"$(/bin/date +%FT%T) copied board handoff\" >> " & logf & "; fi; exit 0"
	on error e
		do shell script "/bin/echo " & quoted form of ((do shell script "/bin/date +%FT%T") & " FAILED " & e) & " >> " & logf
	end try
end run
