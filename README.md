# EmailApp
EmailAPP
Тестовое задание для Messagio

Технологии использованные - Perl + Mojolicious + Redis(streamer) + Mongo

Чтобы запустить приложение (Acceptor) нужно выполнить команду "morbo script/email_server"
приложение работает на localhost:3000.Документация в localhost:3000/docs

Приложение Sender запускается perl sender.pl.
Оно в бесконечном цикле проверяет наличие неотправленных сообщений в очереди и отправляет их.
(сам бы делал через миньоны,но в задании были указаны технологии,которые необходимо использовать)
email_server.yaml - файл с настройками,отдельно есть флаг delivery. при установленном флаге 1 сообзения отправляются,при 0 - 
шаг с отправлением сообщения пропускается (я использую smtp.yandex.ru, он быстро банит за спам)

з.ы. допыта использования докера у меня нет,свободного времени на его освоение не хватило.
 
