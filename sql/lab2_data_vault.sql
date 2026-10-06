-- Лаб. работа №2, вариант 4
-- Городское спортивное соревнование
-- часть 2 : модель Data Vault (PostgreSQL)
--
-- делал по классической схеме из статьи:
--   хаб (H_)       - только бизнес ключ сущности
--   линк (L_)      - только связи между хабами
--   сателлит (S_)  - все описательные атрибуты + история изменений
-- в каждой таблице служебные поля:
--   load_dts  - когда запись загрузили
--   rec_src   - откуда пришла (система источник)
-- в сателлитах ключ = ключ хаба + load_dts, так храниться история,
-- load_end_dts  заполняется когда пришла новая версия записи
--
-- источник данных это база в 3НФ из первой части (схема nf3)

drop schema if exists dv cascade;
create schema dv;
-- тут тоже везде явно dv. перед именем таблицы


-- ================= ХАБЫ =================

-- вид спорта. бизнес ключ - код вида спорта (как во всерос. реестре видов спорта)
create table dv.h_sport (
    sport_sqn   serial primary key,
    sport_code  varchar(20) not null unique,
    load_dts    timestamp not null default now(),
    rec_src     varchar(50) not null
);

-- площадка
create table dv.h_venue (
    venue_sqn   serial primary key,
    venue_code  varchar(20) not null unique,
    load_dts    timestamp not null default now(),
    rec_src     varchar(50) not null
);

-- соревнование
create table dv.h_competition (
    competition_sqn   serial primary key,
    competition_code  varchar(30) not null unique,   -- напр. GSS-2026-OSEN
    load_dts          timestamp not null default now(),
    rec_src           varchar(50) not null
);

-- возрастная категория
create table dv.h_category (
    category_sqn   serial primary key,
    category_code  varchar(20) not null unique,   -- напр. M18, W14-15
    load_dts       timestamp not null default now(),
    rec_src        varchar(50) not null
);

-- дисциплина
create table dv.h_discipline (
    discipline_sqn   serial primary key,
    discipline_code  varchar(40) not null unique,
    load_dts         timestamp not null default now(),
    rec_src          varchar(50) not null
);

-- команда
create table dv.h_team (
    team_sqn   serial primary key,
    team_code  varchar(20) not null unique,
    load_dts   timestamp not null default now(),
    rec_src    varchar(50) not null
);

-- участник. как бизнес ключ берем номер в реестре спортсменов
-- (фио не годится, бывают однофамильцы)
create table dv.h_participant (
    participant_sqn   serial primary key,
    participant_code  varchar(20) not null unique,
    load_dts          timestamp not null default now(),
    rec_src           varchar(50) not null
);

-- судья, ключ  номер судейского удостоверения
create table dv.h_judge (
    judge_sqn   serial primary key,
    judge_code  varchar(20) not null unique,
    load_dts    timestamp not null default now(),
    rec_src     varchar(50) not null
);


-- ================= ЛИНКИ =================

-- дисциплина проводится в рамках соревнования, по виду спорта,
-- на площадке и для категории. это одна бизнес связь поэтому один линк на 5 хабов
create table dv.l_discipline_setup (
    discipline_setup_sqn  serial primary key,
    discipline_sqn   integer not null references dv.h_discipline(discipline_sqn),
    competition_sqn  integer not null references dv.h_competition(competition_sqn),
    sport_sqn        integer not null references dv.h_sport(sport_sqn),
    venue_sqn        integer not null references dv.h_venue(venue_sqn),
    category_sqn     integer not null references dv.h_category(category_sqn),
    load_dts         timestamp not null default now(),
    rec_src          varchar(50) not null,
    unique (discipline_sqn, competition_sqn, sport_sqn, venue_sqn, category_sqn)
);

-- участник состоит в команде
-- в 3нф это просто поле team_id, но в DV связи всегда только линками,
-- зато если человек перейдет в другую команду история сохранится
create table dv.l_participant_team (
    participant_team_sqn  serial primary key,
    participant_sqn  integer not null references dv.h_participant(participant_sqn),
    team_sqn         integer not null references dv.h_team(team_sqn),
    load_dts         timestamp not null default now(),
    rec_src          varchar(50) not null,
    unique (participant_sqn, team_sqn)
);

-- заявка участника на дисциплину
create table dv.l_registration (
    registration_sqn  serial primary key,
    participant_sqn   integer not null references dv.h_participant(participant_sqn),
    discipline_sqn    integer not null references dv.h_discipline(discipline_sqn),
    load_dts          timestamp not null default now(),
    rec_src           varchar(50) not null,
    unique (participant_sqn, discipline_sqn)
);

-- судья назначен на дисциплину
create table dv.l_judging (
    judging_sqn     serial primary key,
    judge_sqn       integer not null references dv.h_judge(judge_sqn),
    discipline_sqn  integer not null references dv.h_discipline(discipline_sqn),
    load_dts        timestamp not null default now(),
    rec_src         varchar(50) not null,
    unique (judge_sqn, discipline_sqn)
);


-- ================= САТЕЛЛИТЫ =================
-- у всех pk составной: ссылка на хаб/линк + load_dts

create table dv.s_sport (
    sport_sqn     integer not null references dv.h_sport(sport_sqn),
    load_dts      timestamp not null default now(),
    load_end_dts  timestamp,
    rec_src       varchar(50) not null,
    name          varchar(100) not null,
    description   text,
    primary key (sport_sqn, load_dts)
);

create table dv.s_venue (
    venue_sqn     integer not null references dv.h_venue(venue_sqn),
    load_dts      timestamp not null default now(),
    load_end_dts  timestamp,
    rec_src       varchar(50) not null,
    name          varchar(150) not null,
    address       varchar(255) not null,
    district      varchar(100),
    capacity      integer,
    primary key (venue_sqn, load_dts)
);

create table dv.s_competition (
    competition_sqn  integer not null references dv.h_competition(competition_sqn),
    load_dts         timestamp not null default now(),
    load_end_dts     timestamp,
    rec_src          varchar(50) not null,
    name             varchar(200) not null,
    start_date       date not null,
    end_date         date not null,
    organizer        varchar(200),
    status           varchar(20) not null,   -- статус меняется часто, история как раз тут пригодится
    primary key (competition_sqn, load_dts)
);

create table dv.s_category (
    category_sqn  integer not null references dv.h_category(category_sqn),
    load_dts      timestamp not null default now(),
    load_end_dts  timestamp,
    rec_src       varchar(50) not null,
    name          varchar(100) not null,
    gender        char(1) not null,
    age_from      smallint not null,
    age_to        smallint,
    primary key (category_sqn, load_dts)
);

create table dv.s_discipline (
    discipline_sqn    integer not null references dv.h_discipline(discipline_sqn),
    load_dts          timestamp not null default now(),
    load_end_dts      timestamp,
    rec_src           varchar(50) not null,
    name              varchar(200) not null,
    start_time        timestamp not null,
    max_participants  integer,
    primary key (discipline_sqn, load_dts)
);

create table dv.s_team (
    team_sqn      integer not null references dv.h_team(team_sqn),
    load_dts      timestamp not null default now(),
    load_end_dts  timestamp,
    rec_src       varchar(50) not null,
    name          varchar(150) not null,
    district      varchar(100),
    coach_name    varchar(150),
    primary key (team_sqn, load_dts)
);

-- персональные данные участника вынес в отдельный сателлит от разряда,
-- разряд меняется чаще, а фио и др почти никогда (так меньше дублей при загрузке)
create table dv.s_participant_person (
    participant_sqn  integer not null references dv.h_participant(participant_sqn),
    load_dts         timestamp not null default now(),
    load_end_dts     timestamp,
    rec_src          varchar(50) not null,
    last_name        varchar(50) not null,
    first_name       varchar(50) not null,
    middle_name      varchar(50),
    birth_date       date not null,
    gender           char(1) not null,
    phone            varchar(20),
    primary key (participant_sqn, load_dts)
);

create table dv.s_participant_rank (
    participant_sqn  integer not null references dv.h_participant(participant_sqn),
    load_dts         timestamp not null default now(),
    load_end_dts     timestamp,
    rec_src          varchar(50) not null,
    sport_rank       varchar(30),
    primary key (participant_sqn, load_dts)
);

create table dv.s_judge (
    judge_sqn       integer not null references dv.h_judge(judge_sqn),
    load_dts        timestamp not null default now(),
    load_end_dts    timestamp,
    rec_src         varchar(50) not null,
    last_name       varchar(50) not null,
    first_name      varchar(50) not null,
    middle_name     varchar(50),
    judge_category  varchar(30),
    phone           varchar(20),
    primary key (judge_sqn, load_dts)
);

-- сателлит линка заявки: статус, номер, результат и место
-- результат появляется позже чем заявка, поэтому будет новая версия строки
create table dv.s_registration (
    registration_sqn  integer not null references dv.l_registration(registration_sqn),
    load_dts          timestamp not null default now(),
    load_end_dts      timestamp,
    rec_src           varchar(50) not null,
    reg_date          date not null,
    start_number      integer,
    status            varchar(20) not null,
    result_value      varchar(30),
    place             smallint,
    primary key (registration_sqn, load_dts)
);

-- сателлит линка судейства, роль судьи на дисциплине
create table dv.s_judging (
    judging_sqn   integer not null references dv.l_judging(judging_sqn),
    load_dts      timestamp not null default now(),
    load_end_dts  timestamp,
    rec_src       varchar(50) not null,
    role          varchar(50) not null,
    primary key (judging_sqn, load_dts)
);


-- индексы по ссылкам в линках (первая колонка уже покрыта unique)
create index ix_lds_comp     on dv.l_discipline_setup(competition_sqn);
create index ix_lds_sport    on dv.l_discipline_setup(sport_sqn);
create index ix_lds_venue    on dv.l_discipline_setup(venue_sqn);
create index ix_lds_category on dv.l_discipline_setup(category_sqn);
create index ix_lpt_team     on dv.l_participant_team(team_sqn);
create index ix_lreg_disc    on dv.l_registration(discipline_sqn);
create index ix_ljud_disc    on dv.l_judging(discipline_sqn);


comment on schema dv is 'Хранилище Data Vault: городское спортивное соревнование';
comment on table dv.h_sport        is 'Хаб: вид спорта';
comment on table dv.h_venue        is 'Хаб: площадка';
comment on table dv.h_competition  is 'Хаб: соревнование';
comment on table dv.h_category     is 'Хаб: возрастная категория';
comment on table dv.h_discipline   is 'Хаб: дисциплина';
comment on table dv.h_team         is 'Хаб: команда';
comment on table dv.h_participant  is 'Хаб: участник';
comment on table dv.h_judge        is 'Хаб: судья';
comment on table dv.l_discipline_setup is 'Линк: дисциплина - соревнование - вид спорта - площадка - категория';
comment on table dv.l_participant_team is 'Линк: участник - команда';
comment on table dv.l_registration     is 'Линк: заявка участника на дисциплину';
comment on table dv.l_judging          is 'Линк: судья - дисциплина';
comment on table dv.s_registration     is 'Сателлит заявки: статус, результат, место';
comment on table dv.s_judging          is 'Сателлит судейства: роль судьи';
