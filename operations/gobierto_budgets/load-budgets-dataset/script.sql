CREATE TEMP TABLE budgets_raw(
  eixestrg TEXT,
  objectiu TEXT,
  programa TEXT,
  prgdatainici TEXT,
  prgdatafi TEXT,
  subprograma TEXT,
  subprgdatainici TEXT,
  subprgdatafi TEXT,
  prjcodi TEXT,
  prjnom TEXT,
  prjdatainiestim TEXT,
  prjdatafiestim TEXT,
  prjtipus TEXT,
  prjprioritat TEXT,
  prjestat TEXT,
  prjnom_presp_1 TEXT,
  prjnom_presp_2 TEXT,
  prjnom_presp_3 TEXT,
  prjnom_presp_4 TEXT,
  prjimpestim TEXT,
  prjhoresestim TEXT,
  paranyprs TEXT,
  parclsorg_1d TEXT,
  parclsorg_2d TEXT,
  parclsorg_3d TEXT,
  parclsorg_4d TEXT,
  parclsorg TEXT,
  parclsfun_grp TEXT,
  parclsfun_1d TEXT,
  parclsfun_2d TEXT,
  parclsfun TEXT,
  parzona TEXT,
  parcapitol TEXT,
  parclseco_2d TEXT,
  parclseco_3d TEXT,
  parclseco TEXT,
  tippartida TEXT,
  parcodi TEXT,
  parnom TEXT,
  parimport TEXT,
  impassig_v1 TEXT,
  impassig_v2 TEXT,
  impassig_v3 TEXT,
  impassig TEXT,
  impassig_ini TEXT,
  codiacum TEXT,
  desacum TEXT,
  anyacum TEXT,
  importprjpardefin TEXT,
  importprjpartotal TEXT,
  importpardefin TEXT,
  importpartotal TEXT
);

CREATE TEMP TABLE budgets_transformed(
  eixestrg TEXT,
  objectiu TEXT,
  programa TEXT,
  prgdatainici DATE,
  prgdatafi DATE,
  subprograma TEXT,
  subprgdatainici DATE,
  subprgdatafi DATE,
  prjcodi TEXT,
  prjnom TEXT,
  prjdatainiestim DATE,
  prjdatafiestim DATE,
  prjtipus TEXT,
  prjprioritat TEXT,
  prjestat TEXT,
  prjnom_presp_1 TEXT,
  prjnom_presp_2 TEXT,
  prjnom_presp_3 TEXT,
  prjnom_presp_4 TEXT,
  prjimpestim TEXT,
  prjhoresestim TEXT,
  paranyprs INTEGER,
  parclsorg_1d TEXT,
  parclsorg_2d TEXT,
  parclsorg_3d TEXT,
  parclsorg_4d TEXT,
  parclsorg TEXT,
  parclsfun_grp TEXT,
  parclsfun_1d TEXT,
  parclsfun_2d TEXT,
  parclsfun TEXT,
  parzona TEXT,
  parcapitol TEXT,
  parclseco_2d TEXT,
  parclseco_3d TEXT,
  parclseco TEXT,
  tippartida TEXT,
  parcodi TEXT,
  parnom TEXT,
  parimport NUMERIC,
  impassig_v1 NUMERIC,
  impassig_v2 NUMERIC,
  impassig_v3 NUMERIC,
  impassig NUMERIC,
  impassig_ini NUMERIC,
  codiacum TEXT,
  desacum TEXT,
  anyacum INTEGER,
  importprjpardefin NUMERIC,
  importprjpartotal NUMERIC,
  importpardefin NUMERIC,
  importpartotal NUMERIC,
  code_with_zone TEXT
);

DROP TABLE IF EXISTS mataro_budgets;
CREATE TABLE mataro_budgets(
  eixestrg TEXT,
  objectiu TEXT,
  programa TEXT,
  prgdatainici DATE,
  prgdatafi DATE,
  subprograma TEXT,
  subprgdatainici DATE,
  subprgdatafi DATE,
  prjcodi TEXT,
  prjnom TEXT,
  prjdatainiestim DATE,
  prjdatafiestim DATE,
  prjtipus TEXT,
  prjprioritat TEXT,
  prjestat TEXT,
  prjnom_presp_1 TEXT,
  prjnom_presp_2 TEXT,
  prjnom_presp_3 TEXT,
  prjnom_presp_4 TEXT,
  prjimpestim TEXT,
  prjhoresestim TEXT,
  paranyprs INTEGER,
  parclsorg_1d TEXT,
  parclsorg_2d TEXT,
  parclsorg_3d TEXT,
  parclsorg_4d TEXT,
  parclsorg TEXT,
  parclsfun_grp TEXT,
  parclsfun_1d TEXT,
  parclsfun_2d TEXT,
  parclsfun TEXT,
  parzona TEXT,
  parcapitol TEXT,
  parclseco_2d TEXT,
  parclseco_3d TEXT,
  parclseco TEXT,
  tippartida TEXT,
  parcodi TEXT,
  parnom TEXT,
  parimport NUMERIC,
  impassig_v1 NUMERIC,
  impassig_v2 NUMERIC,
  impassig_v3 NUMERIC,
  impassig NUMERIC,
  impassig_ini NUMERIC,
  codiacum TEXT,
  desacum TEXT,
  anyacum INTEGER,
  importprjpardefin NUMERIC,
  importprjpartotal NUMERIC,
  importpardefin NUMERIC,
  importpartotal NUMERIC,
  code_with_zone TEXT
);

CREATE FUNCTION transform_raw_to_integer(text) RETURNS integer AS $$
    SELECT (case when $1 = '' then NULL else $1::integer end) AS result;
$$ LANGUAGE SQL;

CREATE FUNCTION transform_raw_to_numeric(text) RETURNS numeric AS $$
    SELECT (case when $1 = '' then NULL else $1::numeric end) AS result;
$$ LANGUAGE SQL;

CREATE FUNCTION transform_raw_to_text(text) RETURNS text AS $$
    SELECT (case when $1 = '' then NULL else $1 end) AS result;
$$ LANGUAGE SQL;

CREATE FUNCTION transform_raw_to_date(text) RETURNS date AS $$
    SELECT (case when $1 = '' then NULL else to_date($1,'DD-MON-YYYY') end) AS result;
$$ LANGUAGE SQL;

CREATE FUNCTION add_zone_to_code(text, text) RETURNS text AS $$
    SELECT (case when $2 = '-' then $1 else regexp_replace($1, '^(\d+\.\d+)\.','\1' || substring($2, 1,1) || '.') end) AS result;
$$ LANGUAGE SQL;

\COPY budgets_raw (eixestrg, objectiu, programa, prgdatainici, prgdatafi, subprograma, subprgdatainici, subprgdatafi, prjcodi, prjnom, prjdatainiestim, prjdatafiestim, prjtipus, prjprioritat, prjestat, prjnom_presp_1, prjnom_presp_2, prjnom_presp_3, prjnom_presp_4, prjimpestim, prjhoresestim, paranyprs, parclsorg_1d, parclsorg_2d, parclsorg_3d, parclsorg_4d, parclsorg, parclsfun_grp, parclsfun_1d, parclsfun_2d, parclsfun, parzona, parcapitol, parclseco_2d, parclseco_3d, parclseco, tippartida, parcodi, parnom, parimport, impassig_v1, impassig_v2, impassig_v3, impassig, impassig_ini, codiacum, desacum, anyacum, importprjpardefin, importprjpartotal, importpardefin, importpartotal) FROM '/tmp/mataro/pressupost_2017_utf8_clean.csv' DELIMITER ',' CSV HEADER NULL '';

\COPY budgets_raw (eixestrg, objectiu, programa, prgdatainici, prgdatafi, subprograma, subprgdatainici, subprgdatafi, prjcodi, prjnom, prjdatainiestim, prjdatafiestim, prjtipus, prjprioritat, prjestat, prjnom_presp_1, prjnom_presp_2, prjnom_presp_3, prjnom_presp_4, prjimpestim, prjhoresestim, paranyprs, parclsorg_1d, parclsorg_2d, parclsorg_3d, parclsorg_4d, parclsorg, parclsfun_grp, parclsfun_1d, parclsfun_2d, parclsfun, parzona, parcapitol, parclseco_2d, parclseco_3d, parclseco, tippartida, parcodi, parnom, parimport, impassig_v1, impassig_v2, impassig_v3, impassig, impassig_ini, codiacum, desacum, anyacum, importprjpardefin, importprjpartotal, importpardefin, importpartotal) FROM '/tmp/mataro/pressupost_2018_utf8_clean.csv' DELIMITER ',' CSV HEADER NULL '';

\COPY budgets_raw (eixestrg, objectiu, programa, prgdatainici, prgdatafi, subprograma, subprgdatainici, subprgdatafi, prjcodi, prjnom, prjdatainiestim, prjdatafiestim, prjtipus, prjprioritat, prjestat, prjnom_presp_1, prjnom_presp_2, prjnom_presp_3, prjnom_presp_4, prjimpestim, prjhoresestim, paranyprs, parclsorg_1d, parclsorg_2d, parclsorg_3d, parclsorg_4d, parclsorg, parclsfun_grp, parclsfun_1d, parclsfun_2d, parclsfun, parzona, parcapitol, parclseco_2d, parclseco_3d, parclseco, tippartida, parcodi, parnom, parimport, impassig_v1, impassig_v2, impassig_v3, impassig, impassig_ini, codiacum, desacum, anyacum, importprjpardefin, importprjpartotal, importpardefin, importpartotal) FROM '/tmp/mataro/pressupost_2019_utf8_clean.csv' DELIMITER ',' CSV HEADER NULL '';

INSERT INTO budgets_transformed (
  eixestrg, objectiu, programa, prgdatainici, prgdatafi, subprograma, subprgdatainici, subprgdatafi, prjcodi, prjnom, prjdatainiestim, prjdatafiestim, prjtipus, prjprioritat, prjestat, prjnom_presp_1, prjnom_presp_2, prjnom_presp_3, prjnom_presp_4, prjimpestim, prjhoresestim, paranyprs, parclsorg_1d, parclsorg_2d, parclsorg_3d, parclsorg_4d, parclsorg, parclsfun_grp, parclsfun_1d, parclsfun_2d, parclsfun, parzona, parcapitol, parclseco_2d, parclseco_3d, parclseco, tippartida, parcodi, parnom, parimport, impassig_v1, impassig_v2, impassig_v3, impassig, impassig_ini, codiacum, desacum, anyacum, importprjpardefin, importprjpartotal, importpardefin, importpartotal, code_with_zone
)
  SELECT
    transform_raw_to_text(eixestrg),
    transform_raw_to_text(objectiu),
    transform_raw_to_text(programa),
    transform_raw_to_date(prgdatainici),
    transform_raw_to_date(prgdatafi),
    transform_raw_to_text(subprograma),
    transform_raw_to_date(subprgdatainici),
    transform_raw_to_date(subprgdatafi),
    transform_raw_to_text(prjcodi),
    transform_raw_to_text(prjnom),
    transform_raw_to_date(prjdatainiestim),
    transform_raw_to_date(prjdatafiestim),
    transform_raw_to_text(prjtipus),
    transform_raw_to_text(prjprioritat),
    transform_raw_to_text(prjestat),
    transform_raw_to_text(prjnom_presp_1),
    transform_raw_to_text(prjnom_presp_2),
    transform_raw_to_text(prjnom_presp_3),
    transform_raw_to_text(prjnom_presp_4),
    transform_raw_to_text(prjimpestim),
    transform_raw_to_text(prjhoresestim),
    transform_raw_to_integer(paranyprs),
    transform_raw_to_text(parclsorg_1d),
    transform_raw_to_text(parclsorg_2d),
    transform_raw_to_text(parclsorg_3d),
    transform_raw_to_text(parclsorg_4d),
    transform_raw_to_text(parclsorg),
    transform_raw_to_text(parclsfun_grp),
    transform_raw_to_text(parclsfun_1d),
    transform_raw_to_text(parclsfun_2d),
    transform_raw_to_text(parclsfun),
    transform_raw_to_text(parzona),
    transform_raw_to_text(parcapitol),
    transform_raw_to_text(parclseco_2d),
    transform_raw_to_text(parclseco_3d),
    transform_raw_to_text(parclseco),
    transform_raw_to_text(tippartida),
    transform_raw_to_text(parcodi),
    transform_raw_to_text(parnom),
    transform_raw_to_numeric(parimport),
    transform_raw_to_numeric(impassig_v1),
    transform_raw_to_numeric(impassig_v2),
    transform_raw_to_numeric(impassig_v3),
    transform_raw_to_numeric(impassig),
    transform_raw_to_numeric(impassig_ini),
    transform_raw_to_text(codiacum),
    transform_raw_to_text(desacum),
    transform_raw_to_integer(anyacum),
    transform_raw_to_numeric(importprjpardefin),
    transform_raw_to_numeric(importprjpartotal),
    transform_raw_to_numeric(importpardefin),
    transform_raw_to_numeric(importpartotal),
    add_zone_to_code(parcodi, parzona)
from budgets_raw;

insert into mataro_budgets(
  eixestrg, objectiu, programa, prgdatainici, prgdatafi, subprograma, subprgdatainici, subprgdatafi, prjcodi, prjnom, prjdatainiestim, prjdatafiestim, prjtipus, prjprioritat, prjestat, prjnom_presp_1, prjnom_presp_2, prjnom_presp_3, prjnom_presp_4, prjimpestim, prjhoresestim, paranyprs, parclsorg_1d, parclsorg_2d, parclsorg_3d, parclsorg_4d, parclsorg, parclsfun_grp, parclsfun_1d, parclsfun_2d, parclsfun, parzona, parcapitol, parclseco_2d, parclseco_3d, parclseco, tippartida, parcodi, parnom, parimport, impassig_v1, impassig_v2, impassig_v3, impassig, impassig_ini, codiacum, desacum, anyacum, importprjpardefin, importprjpartotal, importpardefin, importpartotal, code_with_zone
)
SELECT * from budgets_transformed;

DROP FUNCTION IF EXISTS transform_raw_to_integer(text);
DROP FUNCTION IF EXISTS transform_raw_to_numeric(text);
DROP FUNCTION IF EXISTS transform_raw_to_text(text);
DROP FUNCTION IF EXISTS transform_raw_to_date(text);
DROP FUNCTION IF EXISTS add_zone_to_code(text, text);
