-- Лаб. работа №2,  вариант 4
-- Городское спортивное соревнование
-- часть 1 : модель в 3НФ (PostgreSQL)
--
-- все таблицы делаю в отдельной схеме nf3 чтобы не мешались с data vault
-- скрипт можно запускать повторно, в начале схема удаляется

drop schema if exists nf3 cascade;
create schema nf3;
-- имя схемы пишу перед каждой таблицей (nf3.) ,  иначе dbeaver кидает таблицы в public


-- справочник видов спорта
create table nf3.sport (
    sport_id     serial primary key,
    name         varchar(100) not null unique,  
    description  text                          
);


-- площадки где проходят старты (стадионы, бассейны, спортзалы)
create table nf3.venue (
    venue_id   serial primary key,
    name       varchar(150) not null,
    address    varchar(255) not null,
    district   varchar(100),          -- район города
    capacity   integer check (capacity > 0)   -- вместимость, сколько зрителей влезает
);


-- само соревнование. одно соревнование может быть по нескольким видам спорта
-- поэтому вид спорта тут не храним, он  уходит в дисциплину
create table nf3.competition (
    competition_id  serial primary key,
    name            varchar(200) not null,
    start_date      date not null,
    end_date        date not null,
    organizer       varchar(200),   
    status          varchar(20) not null default 'планируется'
                    check (status in ('планируется','идет','завершено','отменено')),
    check (end_date >= start_date)
);


-- возрастные категории, пол тоже сюда 
create table nf3.age_category (
    category_id  serial primary key,
    name         varchar(100) not null,
    gender       char(1) not null check (gender in ('М','Ж')),
    age_from     smallint not null,
    age_to       smallint,     -- null значит без ограничения сверху
    check (age_to is null or age_to >= age_from)
);


-- дисциплина = конкретный вид программы  внутри соревнования
-- связывает соревнование, вид спорта, площадку и категорию
create table nf3.discipline (
    discipline_id   serial primary key,
    competition_id  integer not null references nf3.competition(competition_id),
    sport_id        integer not null references nf3.sport(sport_id),
    venue_id        integer not null references nf3.venue(venue_id),
    category_id     integer not null references nf3.age_category(category_id),
    name            varchar(200) not null,
    start_time      timestamp not null,     -- время старта
    max_participants integer check (max_participants > 0)
);


-- команды (от школ, клубов, районов)
create table nf3.team (
    team_id     serial primary key,
    name        varchar(150) not null unique,
    district    varchar(100),
    coach_name  varchar(150)      
);


-- участники. команда не обязательна, бывают личные заявки
create table nf3.participant (
    participant_id  serial primary key,
    last_name       varchar(50) not null,
    first_name      varchar(50) not null,
    middle_name     varchar(50),
    birth_date      date not null,
    gender          char(1) not null check (gender in ('М','Ж')),
    sport_rank      varchar(30),     -- разряд: 1 взрослый, КМС, МС ...
    phone           varchar(20),
    team_id         integer references nf3.team(team_id)
);


-- судьи
create table nf3.judge (
    judge_id     serial primary key,
    last_name    varchar(50) not null,
    first_name   varchar(50) not null,
    middle_name  varchar(50),
    judge_category varchar(30),   -- судейская категория (ВК, 1я, 2я ...)
    phone        varchar(20)
);


-- заявка участника на дисциплину, тут же результат и занятое место
-- один и тот же человек не может заявиться  в одну дисциплину дважды
create table nf3.registration (
    registration_id  serial primary key,
    participant_id   integer not null references nf3.participant(participant_id),
    discipline_id    integer not null references nf3.discipline(discipline_id),
    reg_date         date not null default current_date,
    start_number     integer,      -- стартовый номер
    status           varchar(20) not null default 'подана'
                     check (status in ('подана','допущен','снят','дисквалифицирован')),
    result_value     varchar(30), 
    place            smallint check (place > 0),
    unique (participant_id, discipline_id),
    unique (discipline_id, start_number)
);


-- какие судьи судят какую дисциплину (многие ко многим)
create table nf3.judging (
    discipline_id  integer not null references nf3.discipline(discipline_id),
    judge_id       integer not null references nf3.judge(judge_id),
    role           varchar(50) not null default 'судья',   -- главный судья, секретарь, хронометрист
    primary key (discipline_id, judge_id)
);


-- индексы на внешние ключи, постгрес сам их не создает
create index ix_discipline_comp   on nf3.discipline(competition_id);
create index ix_discipline_sport  on nf3.discipline(sport_id);
create index ix_discipline_venue  on nf3.discipline(venue_id);
create index ix_participant_team  on nf3.participant(team_id);
create index ix_registration_disc on nf3.registration(discipline_id);
create index ix_judging_judge     on nf3.judging(judge_id);


-- коментарии к таблицам чтобы было видно в dbeaver
comment on table nf3.sport        is 'Виды спорта';
comment on table nf3.venue        is 'Спортивные площадки';
comment on table nf3.competition  is 'Городские соревнования';
comment on table nf3.age_category is 'Возрастные категории участников';
comment on table nf3.discipline   is 'Дисциплины (виды программы) соревнования';
comment on table nf3.team         is 'Команды';
comment on table nf3.participant  is 'Участники (спортсмены)';
comment on table nf3.judge        is 'Судьи';
comment on table nf3.registration is 'Заявки участников на дисциплины и результаты';
comment on table nf3.judging      is 'Назначение судей на дисциплины';
