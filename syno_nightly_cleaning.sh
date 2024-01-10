#clean books folders
find /volume2/media/books -name "*.nfo" -delete
find /volume2/media/books -name "*.torrent" -delete
find /volume2/media/books -name "*.DS_STORE" -delete
find /volume2/media/books -empty -type d -delete

#clean games folders
find /volume2/media/games -name "*.nfo" -delete
find /volume2/media/games -name "*.torrent" -delete
find /volume2/media/games -name "*.DS_STORE" -delete
find /volume2/media/games -empty -type d -delete

#clean movies folders
find /volume2/media/movies -name "*.nfo" -delete
find /volume2/media/movies -name "*.torrent" -delete
find /volume2/media/movies -name "*.DS_STORE" -delete
find /volume2/media/movies -empty -type d -delete

#clean music folders
find /volume2/media/music -name "*.jpg" -delete
find /volume2/media/music -name "*.jpeg" -delete
find /volume2/media/music -name "*.png" -delete
find /volume2/media/music -name "*.m3u" -delete
find /volume2/media/music -name "*.cue" -delete
find /volume2/media/music -name "*.log" -delete
find /volume2/media/music -name "*.txt" -delete
find /volume2/media/music -name "*.nfo" -delete
find /volume2/media/music -name "*.torrent" -delete
find /volume2/media/music -name "*.DS_STORE" -delete
find /volume2/media/music -empty -type d -delete

#clean tv folders
find /volume2/media/tv -name "*.nfo" -delete
find /volume2/media/tv -name "*.torrent" -delete
find /volume2/media/tv -name "*.DS_STORE" -delete
find /volume2/media/tv -empty -type d -delete

#clean YouTube folders
find /volume2/media/youtube -name "*.nfo" -delete
find /volume2/media/youtube -name "*.torrent" -delete
find /volume2/media/youtube -name "*.DS_STORE" -delete

#prune docker for stopped containers, unused networks, volumes, images, and caches
docker system prune --volumes --force --all
