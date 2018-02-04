# Telegram + Perl (Part 1)

В интернетах появляется множество статей по написанию Telegram ботов на различных языках и с применением различных технологий. Perl в этом списке не является исключением [тыц](https://habrahabr.ru/post/333586/). Также существует ряд модулей на [cpan](https://metacpan.org/search?size=20&q=telegram) и даже некий фреймворк.   
Но я хотел бы предоставить простое описание минимальной структуры самого бота.

Работа с API здесь рассматриваться не будет, так как официальная [документация](https://core.telegram.org/bots/api) предоставляет самую полную информацию. Для приёма сообщений будем использовать популярный Perl web framework Mojolicious, но основной функционал постараемся выстраивать так, чтобы мы в любой момент могли отвязаться от моджо и перевести свой проект на что-то другое.


Изложенное ниже может быть полезно если:

* У вас уже есть telegram бот на perl и вы рассматриваете альтернативные решения.

* Вы желаете создать бота, гибкого к последующему расширению функционала (не зависимо от выбранного языка и фреймворка).

* Теряетесь в выборе инструмента.

* Вы хотите начать писать ботов, но вообще не знаете с чего начать.

В первой части мы рассмотрим минимум для приёма и обработки сообщений собственного бота, в дальнейшем постепенно углубимся до вариантов интеграции с внешней системой, авторизации, учёта пользователей, всяческих возможностей расширения функционала и вариантов использования.

## Подготовка

Для начала работы у вас уже должен быть настроенный nginx с установленным SSL сертификатом. Если с этим есть сложности, то стоит заглянуть сюда [тыц](https://habrahabr.ru/post/318952/). 

Пропишем локейшн для доступа к нашему боту:

<pre>
location /callback {
	proxy_pass http://localhost:3000;
	}
</pre>

Устанавливаем Mojolicious:

`$ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojolicious`

Для нашей задачи вполне могло хватить Mojo::Lite, но мы создадим полноценный Моjo проект. 

`$ mojo generate app Tbot`

Далее создадим самого бота, если вы этого ещё не сделали. 
Добавляем в телеграм [BotFather](https://telegram.me/botfather). В окне команд выбираем /newbot и следуем подсказкам. Наиболее полную информацию можно подсмотреть [тут](https://core.telegram.org/bots). 

После заполнения всех запросов мы получили токен `“Use this token to access the HTTP API: <token>”`. 

Именно этот `<token>` нам и понадобится далее.

Установим WebHook следующего вида:

`"https://api.telegram.org/<token>/setWebhook?url=https://domain/callback/<callback_token>"`

Где callback_token- абсолютно рандомное значение, но можно просто взять часть последовательности символов из token.

Получится примерно следующее:

`wget -O - "https://api.telegram.org/bot666:JHjlhvLHJBJBlhkbbJHBHJhlbMnInItdA/setWebhook?url=https://test.example.ru/callback/bJHBHJhlbMnInItdA"`

Теперь можем перейти к оживлению нашего бота.

## Базовая конфигурация

Заходим в каталог созданного проекта и начинаем описание основного конфиг файла:

`$ cd tbot`

`$ mkdir log`

`$ mkdir etc`

`$ vim etc/telegram.conf`

Содержимое telegram.conf
<pre>
callback_url	bJHBHJhlbMnInItdA

token		bot666:JHjlhvLHJBJBlhkbbJHBHJhlbMnInItdA
</pre>

Здесь мы вписали  `<callback_token>` и соответственно `<token>`.

У себя вы можете использовать другой, возможно более привычный формат. Например хранить конфиг в yaml или json.
Но, лично для меня, данный формат является более привычным, поэтому напишем код для начитки параметров из конфига (или реализуйте похожим образом свой вариант для выбранного формата).

`$ vim lib/Tbot/Configure.pm`

```perl
package Tbot::Configure;

use utf8;
use strict;
use File::Basename;

my $dirname = dirname(__FILE__);
my $conf_filename = $dirname.'/../../etc/telegram.conf';  # Путь к дефолтному конфигу

sub new {
    my ($class, $options) = @_;
    my $self = bless $options => $class;
    return $self;
}

sub config {
    my $self = shift;
    my $file = shift || $conf_filename;   # Если путь не передан, то используем дефолтный
    open CONF, $file or die "Can't open file $file: $!";
    my $conf = {};
    while ( my $line = <CONF> ) {
 	    if ($line =~ /^([A-z]*)\s*(.*)$/) {
   	        $conf->{ $1 } = $2 if ($1);
   	  	}
   	}
    return $conf;
}

1;
```

Отлично, с конфигом разобрались, переходим к описанию стартового модуля.

`$ vim lib/Tbot.pm`

Стираем всё лишнее и пишем:

```perl
package Tbot;
use Mojo::Base 'Mojolicious';
use Tbot::Configure;

has loger => sub {Mojo::Log->new(path => 'log/tbot.log', level => 'debug')}; # Логирование

has conf => sub {
		my $config = Tbot::Configure->new({});
		my $confapp={};
		$confapp->{config} = $config->config(); # Начитываем наш конфиг
		return $confapp;
};

```
Теперь нам нужно объяснить в роутинге, что принимать сообщения нужно на вебхук с токеном, указанным в конфиге.  
Продолжаем редактировать файл и в стартап пишем следующее:  
```perl
sub startup {
    my $self = shift;
    $self->helper(confapp => sub { $self->app->conf });
    $self->helper(ua => sub { $self->app->agent });
    $self->helper(loger => sub { $self->app->loger});
    my $r = $self->routes;
    $r->post('/callback/'.$self->confapp->{config}->{callback_url})->to('callback#index'); # Подставили токен из конфига
}
1;
```
И самое главное. Создадим файл  
`$ vim lib/Tbot/Controller/Callback.pm `

Именно сюда будет попадать данные, прилетевшие нашему боту. В стартапе мы сами прописали to('callback#index').  
Таким образом, все данные будут переданы в Callback в функцию index. Напишем её.

```perl
package Tbot::Controller::Callback;
use Mojo::Base 'Mojolicious::Controller';
use JSON::XS;
use Data::Dumper;

sub index {
    my $self = shift;
    my $json = $self->req->body;   # Получаем прилетевший json
    my $dath  = decode_json $json; # Преобразуем
    print Dumper($dath);           # Выводим на консоль для дальнейшего ознакомления.
    $self->render(text => "You can do it!", status => 200); # Телеграм удовлетворится любым ответом с кодом 200
}

1;
```
Замечу, что вернуть код 200 крайне желательно, иначе он некоторое время будет продолжать долбиться на вебхуку в попытках доставить столь важное послание.  
На данном этапе мы готовы принимать сообщения с нашего бота. Но пока просто изучим данные, которые к нам приходят.  
По этой информации в дальнейшем будет выстраиваться логика обработки входящих сообщений. С изучения этих данных вы часто будете начинать построение своего функционала для телеграм бота.

Запускаем сервис

`$ morbo script/tbot`

Отправляем боту сообщение и смотрим на вывод.  
Если всё работает, то на этом подготовительную часть можно закончить и приступить к написанию какого-то более менее полезного функционала.

### Подход к архитектуре

Как было указано выше, мы планируем уделить некоторое внимание гибкости и простоте.  
Схема работы должна быть прозрачна для того, кто будет заниматься поддержкой бота (например админу с соседнего цеха).  
Внесение изменений и добавление нового функционала не должны вызывать страданий (или должны быть сведены к минимуму).

Добиться этого можно, максимально отделив основные компоненты друг от друга. Логично, что не стоит складывать в одну кучу источник данных, обработку этих данных и отправку конечного результата. Архитектура будет представлять собой слоёный пирог, где каждый слой обладает своими вкусовыми особенностями.  

## Основной функционал

В качестве примера напишем "Hello world" бота, который будет возвращать нам топ криптовалют по персенталю роста и по суточному обороту. Данные будем забирать через апи биржи в формате json. 

Исходя из задачи, нам нужно реализовать следующие компоненты:

1. Получение id пользователя, получение запрашиваемой команды  
2. Передача на выполнение функции, соответствующей запросу от пользователя  
3. Получение данных с биржи  
4. Подготовка данных к выдаче
5. Отправка сообщения пользователю

Для начала опишем все необходимые компоненты в lib/Tbot.pm  
Откроем файл и приведём его к следующему виду:

```perl
package Tbot;
use Mojo::Base 'Mojolicious';
use Tbot::Configure;
use Tbot::Switch; # В этом модуле будут обрабатываться запросы пользователя
use JSON::XS;

#Используем для отправки сообщений и получения данных с биржи
has agent => sub {Mojo::UserAgent->new};

has mjson => sub {
    return sub {decode_json shift}; # Нам понадобится преобразовывать полученный json
};

has botinput => sub {Tbot::Switch->new};

has conf => sub {
		my $config = Tbot::Configure->new({});
		my $confapp={};
		$confapp->{config} = $config->config();
		return $confapp;
};

has loger => sub {Mojo::Log->new(path => 'log/tbot.log', level => 'debug')};

sub startup {
    my $self = shift;
    $self->helper(mjson => sub { $self->app->mjson});
    $self->helper(confapp => sub { $self->app->conf });
    $self->helper(ua => sub { $self->app->agent });
    $self->helper(loger => sub { $self->app->loger});
    $self->helper(bot_input => sub { $self->app->botinput});
    my $r = $self->routes;
    $r->post('/callback/'.$self->confapp->{config}->{callback_url})->to('callback#index');
}

1;
```

О том, что за Tbot::Switch такой, я расскажу чуть позже. Здесь мы заранее объявили все необходимые компоненты, что значительно упростит нашу жизнь в дальнейшем, так как доступ к ним будет в любом месте нашей программы. А пока отправимся в контроллер  lib/Tbot/Controller/Callback.pm
и приведём код к следующему виду:

```perl
package Tbot::Controller::Callback;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;
    my $json = $self->req->body;
    my $dath  = $self->mjson->($json);
    my %getmsg;
    $self->loger->debug("[Callback]", $json);
```
В данной задаче нас будет интересовать только присланный текст и id пользователя
```perl
    $getmsg{'text'}=$dath->{'message'}->{'text'};  
    $getmsg{'id'}=$dath->{'message'}->{'from'}->{'id'};
```
Убираем из присланного текста лишние символы (можете отредактировать по своему усмотрению)
```perl
    $getmsg{'text'}=~s/[\\\/\`\"\&\@]//sg;
    $self->loger->info("[Callback] text : $getmsg{'text'} id: $getmsg{'id'}");
```
На основе присланного текста мы будем запускать функцию, чьё имя совпадает с эти самым текстом  
Ниже располагается точка входа в тот самый Tbot::Switch
```perl
    $self->bot_input->${\$getmsg{'text'}}($self,$getmsg{'id'}); 
    $self->render(text => "You can do it!", status => 200);
}

1;
```
Не забываем логировать некоторые данные, которые помогут нам, если что-то пойдёт не так.  
Пришло время создать модуль Tbot::Switch.
`$ vim lib/Tbot/Switch.pm`  
```perl
package Tbot::Switch;

use strict;
use Tbot::Bot::Struct;
use Tbot::Bot::Sender;

my $sender=Tbot::Bot::Sender->new();
my $struct=Tbot::Bot::Struct->new();

sub new { bless {}, shift }

sub start {
    my ($class,$self,$id)=@_;
    $sender->send_msg($self,$id,"Hello!");
}
```
В описанную функцию `start` мы должны попасть при присланном сообщении с текстом `start` или `/start`.  
Модуль Tbot::Bot::Struct будет предоставлять нам данные в формате, готовом к отправке пользователю.  
Модуль Tbot::Bot::Sender этой самой отправкой и будет заниматься.  
Соответственно, при получении сообщения `start` пользователю будет отправлено сообщение "Hello!".

Продолжаем редактировать файл. Добавим Две функции, возвращающие данные с биржи.

```perl
sub percent {
    my ($class,$self,$id)=@_;
    my $res=$struct->percentTop($self,"BTC",10);
    $sender->send_msg($self,$id,$res);
}

sub volume {
    my ($class,$self,$id)=@_;
    my $res=$struct->volumeTop($self,"BTC",10);
    $sender->send_msg($self,$id,$res);
}
```
Функции percentTop и volumeTop принимают валюту, по которой будем строить пару и количество пар, которые войдут в наш топ.

Подобный формат описания функционала позволяет без особых трудозатрат добавлять нашему боту новые команды.

Например, если мы захотим добавить топ 5 для пар USDT_- всё что нам потребуется, это написать функцию percent2(или вроде того), которая будет вызывать percentTop($self,"USDT",5). Довольно удобно.

Продолжаем редактирование файла
```perl
sub AUTOLOAD {
    my ($class,$self,$id)=@_;
    $sender->send_msg($self,$id,"unknown command");
}

1;
```
В AUTOLOAD попадёт всё, для чего у нас не реализована функция. Пользователю просто вернём некоторое сообщение.

Теперь можно перейти к описанию модуля Sender. Для данной задачи нам достаточно реализовать только функцию, вызывающую на api метод sendMessage.

`$ vim lib/Tbot/Bot/Sender.pm`

```perl
package Tbot::Bot::Sender;
use Data::Dumper;

my $api_url="https://api.telegram.org/"; # Путь к апи

sub new { bless {}, shift }

sub send_msg {
    my ($class,$self,$id,$text)=@_;
    my $url=$api_url.$self->confapp->{config}->{token}."/sendMessage?chat_id=$id&text=$text"; 
    # Передаём текст и ид пользователя
    my $req=$self->ua->get($url);
    if (my $err=$req->error) {$self->loger->error("[send_msg]", "$err->{code} response: $err->{message}");}
    else {$self->loger->debug("[send_msg]", $req->res->body);}
    # Возможно есть смысл обрабатывать ещё и респонс на предмет ошибок. Для его изучения пока просто залогируем

}

1;
```

Остаётся описать модуль Struct, где и реализованы функции, возвращающие нам значение, готовое к отправке пользователю. В percentTop и volumeTop происходит вся обработка данных, полученых от внешнего источника.

`$ vim lib/Tbot/Bot/Struct.pm`

```perl
package Tbot::Bot::Struct;
use Tbot::Bot::Data;
# В модуле Data располагается источник данных. В нашем случае это api биржи
my $api=Tbot::Bot::Data->new();

sub new { bless {}, shift }

sub percentTop(){
    # На вход принимаем наименование пары и количество пар в топе
    my ($class,$self,$coin,$top)=@_;
    my %value=%{$api->returnTicker($self)};
    my %pairs;
    # Не самый эффективный способ получить интересующие нас значения, но наиболее понятный
        for my $pair (keys %value){
            my $percent=$value{$pair}{'percentChange'}*100;
            $pairs{$pair}=$percent;
        }
    my $res="";
    my $i=0;
        foreach my $pc (sort { $pairs{$b} <=> $pairs{$a} } keys %pairs){
                    if($pc=~/$coin\_/ and $i<$top){
                        my $proc=sprintf("%.2f",$pairs{$pc});
                        $res.="$pc  $proc  $value{$pc}{'last'}\n";
                        $i++;
                    }
        }
    return $res;
}

sub volumeTop(){
    my ($class,$self,$coin,$top)=@_;
    my %value=%{$api->returnTicker($self)};
    my %pairs;
        for my $pair (keys %value){
            my $volume=$value{$pair}{'baseVolume'};
            $pairs{$pair}=$volume;
        }
    my $res="";
    my $i=0;
        foreach my $pc (sort { $pairs{$b} <=> $pairs{$a} } keys %pairs){
                    if($pc=~/$coin\_/ and $i<$top){
                        $res.="$pc  $pairs{$pc}  $value{$pc}{'last'}\n";
                        $i++;
                    }
        }
    return $res;
}


1;
```

Модуль Data описывает взаимодействие с источником данных. В данном случае мы обращаемся к api биржи.

```perl
package Tbot::Bot::Data;

my $apiUrl='https://poloniex.com/public';

sub new { bless {}, shift }

#===METHODS===

sub returnTicker() {
    my ($class,$self) = @_;
    my $url=$apiUrl.'?command='.'returnTicker';
    my $value=$self->ua->get($url)->res->json;
    return $value;
}

1;
```

На этом описание функционала полностью завершено. Должна получиться следующая структура:
<pre>
├── etc
│   └── telegram.conf
├── lib
│   ├── Tbot
│   │   ├── Bot
│   │   │   ├── Data.pm
│   │   │   ├── Sender.pm
│   │   │   └── Struct.pm
│   │   ├── Configure.pm
│   │   ├── Controller
│   │   │   └── Callback.pm
│   │   └── Switch.pm
│   └── Tbot.pm
├── log
│   ├── development.log
│   └── tbot.log
├── public
│   └── index.html
├── script
│   └── tbot
├── t
│   └── basic.t
└── templates
    ├── layouts
    │   └── default.html.ep
    ├── not_found.development.html.ep
    └── not_found.html.ep
</pre>

Можно запустить бота и попробовать вызов имеющихся команд. Выглядит это как-то так:

<pre>
/volume
BTC_LTC  2843.99599248  0.01770079
BTC_XRP  2507.65856949  0.00010170
BTC_STR  2481.78291865  0.00004650
BTC_ETH  2467.74157051  0.10199989
BTC_XMR  494.39998425  0.02720000
BTC_BTS  492.40875250  0.00003472
BTC_DOGE  377.06216364  0.00000054
BTC_XEM  377.02959829  0.00006824
BTC_BCH  317.19347977  0.13548367
BTC_SC  309.74659788  0.00000303
</pre>

### Заметки

Не смотря на то, что бот успешно откликается на команды, возвращая результат- функционала, описанного в нашем учебном примере, не достаточно для боевого использования. Когда вы реализуете подобные сервисы, имеет смысл добавить кеширование, так как нельзя гарантировать стабильный отклик внешних сервисов. Пользователей придётся заставлять ждать ответа, а это крайне грустно. Есть несколько способов реализовать кеширование. Например:  
* Параллельно с основным приложением иметь запущенную таску, которая раз в n секунд будет переначитывать данные в кеше
* Начитывать кеш в тот момент, когда пользователь его запросит, установив время протухания(например 5 секунд). Таким образом, когда приходит пользователь мы проверяем данные в кеше, если они там есть, то отдаём, если нет, то получаем данные, отдаём пользователю и наполняем ими кеш. Первому пришедшему придётся подождать.

Какой из подходов выбрать, решать вам, но об этом стоит помнить при разработке подобных сервисов.  
В зависимости от решаемой задачи логика кеширования может отличаться. Например, если вы пишете сервис, который сообщает погоду на текущий день, переначитывать кеш раз в 5 секунд просто не имеет смысла.

### Запуск приложения

Morbo не задумывался как полноценный сервер для запуска приложений. Он является просто инструментом разработки, позволяющим в реальном времени вносить изменения в код работающего приложения.

Для запуска мы будем использовать hypnotoad.  
В lib/Tbot.pm секцию startup добавим следующую строку:

`$self->config(hypnotoad => {listen => ['http://*:3000'],pid_file => 'hypno.pid'});`  
При желании эти настройки можно легко вынести в родной конфиг Mojo.

Не помешает иметь сервис для запуска. Если у вас система с systemd, создадим файл запуска и заполним его:

`# vim /etc/systemd/system/telebot.service`

```
[Unit]
Description=TeleBot
After=network.target
After=nginx.service

[Service]
Type=simple
SyslogIdentifier=telebot
PIDFile=<путь к воркдир бота>hypno.pid
WorkingDirectory=<путь к воркдир бота>
# Из под кого будем запускать
User=User 
Group=Group

ExecStart=/usr/local/bin/hypnotoad  <путь к воркдир бота>script/tbot -f
ExecStop=/usr/local/bin/hypnotoad -s <путь к воркдир бота>script/tbot
ExecReload=/usr/local/bin/hypnotoad <путь к воркдир бота>script/tbot 
#TimeoutSec=60

[Install]
WantedBy=multi-user.target
```

Выполним команду 

`# systemctl enable telebot.service`

`# systemctl daemon-reload`

Вот и всё!

Теперь бота можно запустить просто выполнив команду `service telebot start` 

и для остановки `service telebot stop`.

Весь код доступен [тут](https://github.com/PsyDebug/BotHowTo)
