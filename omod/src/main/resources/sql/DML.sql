
SET @OLD_SQL_MODE=@@SQL_MODE$$
SET SQL_MODE=''$$
DROP PROCEDURE IF EXISTS sp_populate_etl_patient_demographics$$
CREATE PROCEDURE sp_populate_etl_patient_demographics()
BEGIN
-- initial set up of etl_patient_demographics table
SELECT "Processing patient demographics data ", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_patient_demographics(
patient_id,
given_name,
middle_name,
family_name,
Gender,
DOB,
dead,
voided,
death_date
)
select
p.person_id,
p.given_name,
p.middle_name,
p.family_name,
p.gender,
p.birthdate,
p.dead,
p.voided,
p.death_date
FROM (
select
p.person_id,
pn.given_name,
pn.middle_name,
pn.family_name,
p.gender,
p.birthdate,
p.dead,
p.voided,
p.death_date
from person p
left join patient pa on pa.patient_id=p.person_id
left join person_name pn on pn.person_id = p.person_id and pn.voided=0
where p.voided=0
GROUP BY p.person_id
) p
ON DUPLICATE KEY UPDATE given_name = p.given_name, middle_name=p.middle_name, family_name=p.family_name;


-- update etl_patient_demographics with patient attributes: birthplace, citizenship, mother_name, phone number and kin's details
update kenyaemr_etl.etl_patient_demographics d
left outer join
(
select
pa.person_id,
max(if(pat.uuid='8d8718c2-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as birthplace,
max(if(pat.uuid='8d871afc-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as citizenship,
max(if(pat.uuid='8d871d18-c2cc-11de-8d13-0010c6dffd0f', pa.value, null)) as Mother_name,
max(if(pat.uuid='b2c38640-2603-4629-aebd-3b54f33f1e3a', pa.value, null)) as phone_number,
max(if(pat.uuid='342a1d39-c541-4b29-8818-930916f4c2dc', pa.value, null)) as next_of_kin_contact,
max(if(pat.uuid='d0aa9fd1-2ac5-45d8-9c5e-4317c622c8f5', pa.value, null)) as next_of_kin_relationship,
max(if(pat.uuid='7cf22bec-d90a-46ad-9f48-035952261294', pa.value, null)) as next_of_kin_address,
max(if(pat.uuid='830bef6d-b01f-449d-9f8d-ac0fede8dbd3', pa.value, null)) as next_of_kin_name,
max(if(pat.uuid='b8d0b331-1d2d-4a9a-b741-1816f498bdb6', pa.value, null)) as email_address
from person_attribute pa
inner join
(
select
pat.person_attribute_type_id,
pat.name,
pat.uuid
from person_attribute_type pat
where pat.retired=0
) pat on pat.person_attribute_type_id = pa.person_attribute_type_id
and pat.uuid in (
	'8d8718c2-c2cc-11de-8d13-0010c6dffd0f', -- birthplace
	'8d871afc-c2cc-11de-8d13-0010c6dffd0f', -- citizenship
	'8d871d18-c2cc-11de-8d13-0010c6dffd0f', -- mother's name
	'b2c38640-2603-4629-aebd-3b54f33f1e3a', -- telephone contact
	'342a1d39-c541-4b29-8818-930916f4c2dc', -- next of kin's contact
	'd0aa9fd1-2ac5-45d8-9c5e-4317c622c8f5', -- next of kin's relationship
	'7cf22bec-d90a-46ad-9f48-035952261294', -- next of kin's address
	'830bef6d-b01f-449d-9f8d-ac0fede8dbd3', -- next of kin's name
	'b8d0b331-1d2d-4a9a-b741-1816f498bdb6' -- email address

	)
where pa.voided=0
group by pa.person_id
) att on att.person_id = d.patient_id
set d.phone_number=att.phone_number,
	d.next_of_kin=att.next_of_kin_name,
	d.next_of_kin_relationship=att.next_of_kin_relationship,
	d.next_of_kin_phone=att.next_of_kin_contact,
	d.phone_number=att.phone_number,
	d.birth_place = att.birthplace,
	d.citizenship = att.citizenship,
	d.email_address=att.email_address;


update kenyaemr_etl.etl_patient_demographics d
join (select pi.patient_id,
max(if(pit.uuid='05ee9cf4-7242-4a17-b4d4-00f707265c8a',pi.identifier,null)) as upn,
max(if(pit.uuid='d8ee3b8c-a8fc-4d6b-af6a-9423be5f8906',pi.identifier,null)) district_reg_number,
max(if(pit.uuid='c4e3caca-2dcc-4dc4-a8d9-513b6e63af91',pi.identifier,null)) Tb_treatment_number,
max(if(pit.uuid='b4d66522-11fc-45c7-83e3-39a1af21ae0d',pi.identifier,null)) Patient_clinic_number,
max(if(pit.uuid='49af6cdc-7968-4abb-bf46-de10d7f4859f',pi.identifier,null)) National_id,
max(if(pit.uuid='0691f522-dd67-4eeb-92c8-af5083baf338',pi.identifier,null)) Hei_id
from patient_identifier pi
join patient_identifier_type pit on pi.identifier_type=pit.patient_identifier_type_id
where voided=0
group by pi.patient_id) pid on pid.patient_id=d.patient_id
set d.unique_patient_no=pid.UPN,
	d.national_id_no=pid.National_id,
	d.patient_clinic_number=pid.Patient_clinic_number,
    d.hei_no=pid.Hei_id,
    d.Tb_no=pid.Tb_treatment_number,
    d.district_reg_no=pid.district_reg_number
;

update kenyaemr_etl.etl_patient_demographics d
join (select o.person_id as patient_id,
max(if(o.concept_id in(1054),cn.name,null))  as marital_status,
max(if(o.concept_id in(1712),cn.name,null))  as education_level
from obs o
join concept_name cn on cn.concept_id=o.value_coded and cn.concept_name_type='FULLY_SPECIFIED'
and cn.locale='en'
where o.concept_id in (1054,1712) and o.voided=0
group by person_id) pstatus on pstatus.patient_id=d.patient_id
set d.marital_status=pstatus.marital_status,
d.education_level=pstatus.education_level;

END$$




-- ------------- populate etl_laboratory_extract  uuid:  --------------------------------

DROP PROCEDURE IF EXISTS sp_populate_etl_laboratory_extract$$
CREATE PROCEDURE sp_populate_etl_laboratory_extract()
BEGIN
SELECT "Processing Laboratory data ", CONCAT("Time: ", NOW());
insert into kenyaemr_etl.etl_laboratory_extract(
  uuid,
  patient_id,
  order_id,
  order_date,
  test_type,
  lab_test_concept,
  order_reason,
  testing_lab,
  result,
  result_date,
  date_created,
  created_by
)
  select
    od.uuid,
    od.patient_id,
    od.order_id,
    date(od.date_activated) order_date,
    od.instructions test_type,
    od.concept_id lab_test_concept,
    od.order_reason,
    od.comment_to_fulfiller as testing_lab,
    o.value_coded as result,
    o.date_created as result_date,
    od.date_created,
    od.orderer
  from orders od
    left join obs o on o.order_id=od.order_id and o.voided=0
  where od.order_action != 'DISCONTINUE'and od.voided=0
;

END$$
-- ----------------------------------- UPDATE DASHBOARD TABLE ---------------------


DROP PROCEDURE IF EXISTS sp_update_dashboard_table$$
CREATE PROCEDURE sp_update_dashboard_table()
BEGIN

DECLARE startDate DATE;
DECLARE endDate DATE;
DECLARE reportingPeriod VARCHAR(20);

SET startDate = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m-01');
SET endDate = DATE_FORMAT(LAST_DAY(NOW() - INTERVAL 1 MONTH), '%Y-%m-%d');
SET reportingPeriod = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%M');

-- CURRENT IN CARE


SELECT "Completed processing dashboard indicators", CONCAT("Time: ", NOW());

END$$



-- ------------- populate etl_patient_triage--------------------------------

DROP PROCEDURE IF EXISTS sp_populate_etl_patient_triage$$
CREATE PROCEDURE sp_populate_etl_patient_triage()
	BEGIN
		SELECT "Processing Patient Triage ", CONCAT("Time: ", NOW());
		INSERT INTO kenyaemr_etl.etl_patient_triage(
			uuid,
			patient_id,
			visit_id,
			visit_date,
			location_id,
			encounter_id,
			encounter_provider,
			date_created,
			visit_reason,
			weight,
			height,
			systolic_pressure,
			diastolic_pressure,
			temperature,
			pulse_rate,
			respiratory_rate,
			oxygen_saturation,
			muac,
			nutritional_status,
			last_menstrual_period,
			voided
		)
			select
				e.uuid,
				e.patient_id,
				e.visit_id,
				date(e.encounter_datetime) as visit_date,
				e.location_id,
				e.encounter_id as encounter_id,
				e.creator,
				e.date_created as date_created,
				max(if(o.concept_id=160430,trim(o.value_text),null)) as visit_reason,
				max(if(o.concept_id=5089,o.value_numeric,null)) as weight,
				max(if(o.concept_id=5090,o.value_numeric,null)) as height,
				max(if(o.concept_id=5085,o.value_numeric,null)) as systolic_pressure,
				max(if(o.concept_id=5086,o.value_numeric,null)) as diastolic_pressure,
				max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
				max(if(o.concept_id=5087,o.value_numeric,null)) as pulse_rate,
				max(if(o.concept_id=5242,o.value_numeric,null)) as respiratory_rate,
				max(if(o.concept_id=5092,o.value_numeric,null)) as oxygen_saturation,
				max(if(o.concept_id=1343,o.value_numeric,null)) as muac,
				max(if(o.concept_id=163300,o.value_coded,null)) as nutritional_status,
				max(if(o.concept_id=1427,date(o.value_datetime),null)) as last_menstrual_period,
				e.voided as voided
			from encounter e
				inner join person p on p.person_id=e.patient_id and p.voided=0
				inner join
				(
					select encounter_type_id, uuid, name from encounter_type where uuid in('d1059fb9-a079-4feb-a749-eedd709ae542')
				) et on et.encounter_type_id=e.encounter_type
				left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
				and o.concept_id in (160430,5089,5090,5085,5086,5088,5087,5242,5092,1343,163300,1427)
			where e.voided=0
			group by e.patient_id, e.encounter_id, visit_date
		;
		SELECT "Completed processing Patient Triage data ", CONCAT("Time: ", NOW());
		END$$



-- ------------- populate etl_progress_note-------------------------

DROP PROCEDURE IF EXISTS sp_populate_etl_progress_note$$
CREATE PROCEDURE sp_populate_etl_progress_note()
  BEGIN
    SELECT "Processing progress form", CONCAT("Time: ", NOW());
    insert into kenyaemr_etl.etl_progress_note(
        uuid,
        provider ,
        patient_id,
        visit_id,
        visit_date,
        location_id,
        encounter_id,
        date_created,
        notes,
        voided
        )
    select
           e.uuid, e.creator as provider,e.patient_id, e.visit_id, e.encounter_datetime as visit_date, e.location_id, e.encounter_id,e.date_created,
           max(if(o.concept_id = 159395, o.value_text, null )) as notes,
           e.voided
    from encounter e
			inner join person p on p.person_id=e.patient_id and p.voided=0
			inner join form f on f.form_id=e.form_id and f.uuid in ("c48ed2a2-0a0f-4f4e-9fed-a79ca3e1a9b9")
      inner join obs o on o.encounter_id = e.encounter_id and o.concept_id in (159395) and o.voided=0
    where e.voided=0
    group by e.encounter_id;
    SELECT "Completed processing progress note", CONCAT("Time: ", NOW());

END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_patient_program$$
CREATE PROCEDURE sp_populate_etl_patient_program()
	BEGIN
		SELECT "Processing patient program ", CONCAT("Time: ", NOW());
		INSERT INTO kenyaemr_etl.etl_patient_program(
			uuid,
			patient_id,
			location_id,
			program,
			date_enrolled,
			date_completed,
			outcome,
			date_created,
			voided
		)
			select
				pp.uuid,
				pp.patient_id,
				pp.location_id,
				p.name,
				pp.date_enrolled,
				pp.date_completed,
				pp.outcome_concept_id,
				pp.date_created,
				pp.voided
			from patient_program pp
				inner join patient pt on pt.patient_id=pp.patient_id and pt.voided=0
				inner join program p on p.program_id=pp.program_id and p.retired=0
        where pp.voided=0
		;
		SELECT "Completed processing patient program data ", CONCAT("Time: ", NOW());
		END$$

-- ------------------- populate patient program discontinuation table -------------

DROP PROCEDURE IF EXISTS sp_populate_etl_patient_program_discontinuation$$
CREATE PROCEDURE sp_populate_etl_patient_program_discontinuation()
	BEGIN
		SELECT "Processing Program (Covid -19 Quarantine and Case Investigation) discontinuations ", CONCAT("Time: ", NOW());
		insert into kenyaemr_etl.etl_patient_program_discontinuation(
			patient_id,
			uuid,
			visit_id,
			encounter_date,
			program_uuid,
			program_name,
			encounter_id,
			discontinuation_reason,
			date_died,
			transfer_facility,
			transfer_date
		)
			select
				e.patient_id,
				e.uuid,
				e.visit_id,
				e.encounter_datetime, -- trying to make use of index
				et.uuid,
				(case et.uuid
				 when '7b118dac-6f61-4466-ad1a-7e01aca077ad' then 'COVID-19 Case Investigation'
				 when '33a3a7be-73ae-11ea-bc55-0242ac130003' then 'COVID-19 Quarantine Program'
				 end) as program_name,
				e.encounter_id,
				max(if(o.concept_id=161555, o.value_coded, null)) as reason_discontinued,
				max(if(o.concept_id=1543, o.value_datetime, null)) as date_died,
				max(if(o.concept_id=159495, left(trim(o.value_text),100), null)) as to_facility,
				max(if(o.concept_id=160649, o.value_datetime, null)) as to_date
			from encounter e
				inner join person p on p.person_id=e.patient_id and p.voided=0
				inner join patient_program pp on pp.patient_id = e.patient_id and date(e.encounter_datetime) = date(pp.date_completed) and pp.voided=0
				inner join obs o on o.encounter_id=e.encounter_id and o.voided=0 and o.concept_id in (161555,1543,159495,160649)
				inner join
				(
					select encounter_type_id, uuid, name from encounter_type where
						uuid in('7b118dac-6f61-4466-ad1a-7e01aca077ad','33a3a7be-73ae-11ea-bc55-0242ac130003')
				) et on et.encounter_type_id=e.encounter_type
			where e.voided=0
			group by e.encounter_id;
		SELECT "Completed processing discontinuation data ", CONCAT("Time: ", NOW());
		END$$

  -- ------------------- populate person address table -------------

DROP PROCEDURE IF EXISTS sp_populate_etl_person_address$$
CREATE PROCEDURE sp_populate_etl_person_address()
  BEGIN
    SELECT "Processing person addresses ", CONCAT("Time: ", NOW());
    INSERT INTO kenyaemr_etl.etl_person_address(
      uuid,
      patient_id,
      county,
      sub_county,
      location,
      ward,
      sub_location,
      village,
      postal_address,
      land_mark,
      voided
    )
      select
        pa.uuid,
        pa.person_id,
        coalesce(pa.country,pa.county_district) county,
        pa.state_province sub_county,
        pa.address6 location,
        pa.address4 ward,
        pa.address5 sub_location,
        pa.city_village village,
        pa.address1 postal_address,
        pa.address2 land_mark,
        pa.voided voided
      from person_address pa
        inner join patient pt on pt.patient_id=pa.person_id and pt.voided=0
      where pa.voided=0
    ;
    SELECT "Completed processing person_address data ", CONCAT("Time: ", NOW());
    END$$


-- ------------------------- process patient contact ------------------------

DROP PROCEDURE IF EXISTS sp_populate_etl_patient_contact$$
CREATE PROCEDURE sp_populate_etl_patient_contact()
	BEGIN
		SELECT "Processing patient contact ", CONCAT("Time: ", NOW());
		INSERT INTO kenyaemr_etl.etl_patient_contact(
      id,
      uuid,
      date_created,
      first_name,
      middle_name,
      last_name,
      sex,
      birth_date,
      physical_address,
      phone_contact,
      patient_related_to,
      patient_id,
      relationship_type,
      appointment_date,
      baseline_hiv_status,
      ipv_outcome,
      marital_status,
      living_with_patient,
      pns_approach,
      contact_listing_decline_reason,
      consented_contact_listing,
      voided
		)
			select
			  pc.id,
			  pc.uuid,
        pc.date_created,
        pc.first_name,
        pc.middle_name,
        pc.last_name,
        pc.sex,
        pc.birth_date,
        pc.physical_address,
        pc.phone_contact,
        pc.patient_related_to,
        pc.patient_id,
        pc.relationship_type,
        pc.appointment_date,
        pc.baseline_hiv_status,
        pc.ipv_outcome,
        pc.marital_status,
        pc.living_with_patient,
        pc.pns_approach,
        pc.contact_listing_decline_reason,
        pc.consented_contact_listing,
        pc.voided
			from kenyaemr_hiv_testing_patient_contact pc
				inner join person p on p.person_id = pc.patient_related_to and p.voided=0
        where pc.voided=0
		;
		SELECT "Completed processing patient contact data ", CONCAT("Time: ", NOW());
		END$$

				-- ------------------------- process contact trace ------------------------

DROP PROCEDURE IF EXISTS sp_populate_etl_client_trace$$
CREATE PROCEDURE sp_populate_etl_client_trace()
	BEGIN
		SELECT "Processing client trace ", CONCAT("Time: ", NOW());
		INSERT INTO kenyaemr_etl.etl_client_trace(
      id,
      uuid,
      date_created,
      encounter_date,
      client_id,
      contact_type,
      status,
      unique_patient_no,
      facility_linked_to,
      health_worker_handed_to,
      remarks,
      appointment_date,
      voided
		)
			select
			  ct.id,
        ct.uuid,
        ct.date_created,
        ct.encounter_date,
        ct.client_id,
        ct.contact_type,
        ct.status,
        ct.unique_patient_no,
        ct.facility_linked_to,
        ct.health_worker_handed_to,
        ct.remarks,
        ct.appointment_date,
        ct.voided
			from kenyaemr_hiv_testing_client_trace ct
				inner join kenyaemr_etl.etl_patient_contact pc on pc.id=ct.client_id and pc.voided=0
				inner join person p on p.person_id = pc.patient_related_to and p.voided=0
			where ct.voided=0
		;
		SELECT "Completed processing client trace data ", CONCAT("Time: ", NOW());
		END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_covid_19_enrolment$$
CREATE PROCEDURE sp_populate_etl_covid_19_enrolment()
	BEGIN
		SELECT "Processing Covid Enrolment ", CONCAT("Time: ", NOW());
-- -------------populate etl_covid_19_enrolment-------------------------
INSERT INTO kenyaemr_etl.etl_covid_19_enrolment(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
sub_county,
county,
detection_point,
date_detected,
onset_symptoms_date,
symptomatic,
fever,
cough,
runny_nose,
diarrhoea,
headache,
muscular_pain,
abdominal_pain,
general_weakness,
sore_throat,
shortness_breath,
vomiting,
confusion,
chest_pain,
joint_pain,
other_symptom,
specify_symptoms,
temperature,
pharyngeal_exudate,
tachypnea,
abnormal_xray,
coma,
conjuctival_injection,
abnormal_lung_auscultation,
seizures,
pregnancy_status,
trimester,
underlying_condition,
cardiovascular_dse_hypertension,
diabetes,
liver_disease,
chronic_neurological_neuromascular_dse,
post_partum,
immunodeficiency,
renal_disease,
chronic_lung_disease,
malignancy,
occupation,
other_signs,
specify_signs,
admitted_to_hospital,
date_of_first_admission,
hospital_name,
date_of_isolation,
patient_ventilated,
health_status_at_reporting,
date_of_death,
recently_travelled,
country_recently_travelled,
city_recently_travelled,
recently_visited_health_facility,
recent_contact_with_infected_person,
recent_contact_with_confirmed_person,
recent_contact_setting,
recent_visit_to_animal_market,
animal_market_name,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=161551,o.value_text,null)) as sub_county,
	max(if(o.concept_id=165197,o.value_text,null)) as county,
  max(if(o.concept_id=161010,(case o.value_coded when 165651 then "Point of entry" when 163488 then "Detected in Community" when 1067 then "Unknown" else "" end),null)) as detection_point,
  max(if(o.concept_id=159948,o.value_datetime,null)) as date_detected,
  max(if(o.concept_id=1730,o.value_datetime,null)) as onset_symptoms_date,
  max(if(o.concept_id=1729,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as symptomatic,
  max(if(o.concept_id=140238,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as fever,
  max(if(o.concept_id=122943,(case o.value_coded when 5226 then "Yes" when 1066 then "No" else "" end),null)) as general_weakness,
  max(if(o.concept_id=143264,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as cough,
  max(if(o.concept_id=163741,(case o.value_coded when 158843 then "Yes" when 1066 then "No" else "" end),null)) as sore_throat,
  max(if(o.concept_id=163336,(case o.value_coded when 113224 then "Yes" when 1066 then "No" else "" end),null)) as runny_nose,
  max(if(o.concept_id=164441,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as shortness_breath,
  max(if(o.concept_id=142412,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as diarrhoea,
  max(if(o.concept_id=122983,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as vomiting,
  max(if(o.concept_id=5219,(case o.value_coded when 139084 then "Yes" when 1066 then "No" else "" end),null)) as headache,
  max(if(o.concept_id=6023,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as confusion,
  max(if(o.concept_id=160388,(case o.value_coded when 133632 then "Yes" when 1066 then "No" else "" end),null)) as muscular_pain,
  max(if(o.concept_id=1123,(case o.value_coded when 120749 then "Yes" when 1066 then "No" else "" end),null)) as chest_pain,
  max(if(o.concept_id=1125,(case o.value_coded when 151 then "Yes" when 1066 then "No" else "" end),null)) as abdominal_pain,
  max(if(o.concept_id=160687,(case o.value_coded when 80 then "Yes" when 1066 then "No" else "" end),null)) as joint_pain,
  max(if(o.concept_id=1838,(case o.value_coded when 139548 then "Yes" else "" end),null)) as other_symptom,
	max(if(o.concept_id=160632,o.value_text,null)) as specify_symptoms,
	max(if(o.concept_id=5088,o.value_numeric,null)) as temperature,
  max(if(o.concept_id=1166,(case o.value_coded when 130305 then "Yes" when 1066 then "No" else "" end),null)) as pharyngeal_exudate,
  max(if(o.concept_id=163309,(case o.value_coded when 517 then "Yes" when 1066 then "No" else "" end),null)) as conjuctival_injection,
  max(if(o.concept_id=125061,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as tachypnea,
  max(if(o.concept_id=122496,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as abnormal_lung_auscultation,
  max(if(o.concept_id=12,(case o.value_coded when 154435 then "Yes" when 1066 then "No" else "" end),null)) as abnormal_xray,
  max(if(o.concept_id=113054,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as seizures,
  max(if(o.concept_id=163043,(case o.value_coded when 144576 then "Yes" when 1066 then "No" else "" end),null)) as coma,
  max(if(o.concept_id=162737,(case o.value_coded when 5622 then "Yes" else "" end),null)) as other_signs,
  max(if(o.concept_id=1391,o.value_text,null)) as specify_signs,
  max(if(o.concept_id=5272,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as pregnancy_status ,
  max(if(o.concept_id=160665,(case o.value_coded when 1721 then "First" when 1722 then "Second" when 1723 then "Third" else "" end),null)) as trimester,
  max(if(o.concept_id=162747,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as underlying_condition,
  max(if(o.concept_id=119270,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as cardiovascular_dse_hypertension,
  max(if(o.concept_id=119481,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as diabetes,
  max(if(o.concept_id=6032,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as liver_disease,
  max(if(o.concept_id=165646,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as chronic_neurological_neuromascular_dse,
  max(if(o.concept_id=129317,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as post_partum,
  max(if(o.concept_id=117277,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as immunodeficiency,
  max(if(o.concept_id=6033,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as renal_disease,
  max(if(o.concept_id=155569,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as chronic_lung_disease,
  max(if(o.concept_id=116031,(case o.value_coded when 1065 then "Yes"  else "" end),null)) as malignancy,
  max(if(o.concept_id=1542,(case o.value_coded when 159465 then "Student" when 165834 then "Working with animals" when 5619 then "Health care worker" when 164831 then "Health laboratory worker" else "" end),null)) as occupation,
  max(if(o.concept_id=163403,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as admitted_to_hospital,
  max(if(o.concept_id=1640,o.value_datetime,null)) as date_of_first_admission,
	max(if(o.concept_id=162724,o.value_text,null)) as hospital_name,
	max(if(o.concept_id=165648,o.value_datetime,null)) as date_of_isolation,
	max(if(o.concept_id=165647,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as patient_ventilated,
	max(if(o.concept_id=159640,(case o.value_coded when 159405 then "Stable" when 159407 then "Severly ill" when 160432 then "Dead" when 1067 then "Unknown" else "" end),null)) as health_status_at_reporting,
  max(if(o.concept_id=1543,o.value_datetime,null)) as date_of_death,
  max(if(o.concept_id=162619,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as recently_travelled,
  max(if(o.concept_id=165198,o.value_text,null)) as country_recently_travelled,
	max(if(o.concept_id=165645,o.value_text,null)) as city_recently_travelled,
	max(if(o.concept_id=162723,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as recently_visited_health_facility,
	max(if(o.concept_id=165850,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as recent_contact_with_infected_person,
	max(if(o.concept_id=162633,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as recent_contact_with_confirmed_person,
	max(if(o.concept_id=163577,(case o.value_coded when 1537 then "Health care setting" when 1536 then "Family setting" when 164406 then "Work place" when 1067 then "Unknown" else "" end),null)) as recent_contact_setting,
	max(if(o.concept_id=165844,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1067 then "Unknown" else "" end),null)) as recent_visit_to_animal_market,
  max(if(o.concept_id=165645,o.value_text,null)) as animal_market_name,
	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join patient_program pp on pp.patient_id = e.patient_id and date(e.encounter_datetime) = date(pp.date_enrolled) and pp.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('0fe60b26-8648-438b-afea-8841dcd993c6')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
													 and o.concept_id in (161551,165851,161010,159948,1730,1729,140238,122943,143264,163741,163336,164441,142412,122983,5219,6023,160388,165197,
                                                1123,1125,160687,1838,160632,5088,1166,163309,125061,122496,12,113054,163043,162737,1391,5272,160665,162747,
																								119270,119481,6032,165646,129317,117277,6033,155569,116031,1542,163403,
                                                1640,162724,165648,165647,159640,1543,162619,165198,165645,162723,165850,162633,163577,165844,165645)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 patient enrolment data ", CONCAT("Time: ", NOW());
END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_contact_tracing_followup$$
CREATE PROCEDURE sp_populate_etl_contact_tracing_followup()
	BEGIN
		SELECT "Processing Covid contact tracing followup ", CONCAT("Time: ", NOW());
-- -------------populate etl_contact_tracing_followup-------------------------
INSERT INTO kenyaemr_etl.etl_contact_tracing_followup(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
fever,
cough,
difficulty_breathing,
sore_throat,
referred_to_hosp,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=140238,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as fever,
	max(if(o.concept_id=143264,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as cough,
	max(if(o.concept_id=164441,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as diffiulty_breathing,
	max(if(o.concept_id=162737,(case o.value_coded when 158843 then "Yes" when 1066 then "No" else "" end),null)) as sore_throat,
	max(if(o.concept_id=1788,(case o.value_coded when 1065 then "Yes" when 1066 then "No" when 1175 then "N/A" else "" end),null)) as referred_to_hosp,
  	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('37ef8f3c-6cd2-11ea-bc55-0242ac130003')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
			and o.concept_id in (140238,143264,164441,162737,1788)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 contact tracing followup data ", CONCAT("Time: ", NOW());
END$$


DROP PROCEDURE IF EXISTS sp_populate_etl_covid_quarantine_enrolment$$
CREATE PROCEDURE sp_populate_etl_covid_quarantine_enrolment()
	BEGIN
		SELECT "Processing Covid quarantine enrolment", CONCAT("Time: ", NOW());
-- -------------populate etl_covid_quarantine_enrolment-------------------------
INSERT INTO kenyaemr_etl.etl_covid_quarantine_enrolment(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
quarantine_center,
type_of_admission,
quarantine_center_trf_from,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=162724,o.value_text,null)) as quarantine_center,
	max(if(o.concept_id=161641,(case o.value_coded when 164144 then "New" when 160563 then "Transfer in" else "" end),null)) as type_of_admission,
	max(if(o.concept_id=161550,o.value_text,null)) as quarantine_center_trf_from,
  	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join patient_program pp on pp.patient_id = e.patient_id and date(e.encounter_datetime) = date(pp.date_enrolled) and pp.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('9a5d57b6-739a-11ea-bc55-0242ac130003')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
													 and o.concept_id in (162724,161641,161550)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 quarantine enrolment data ", CONCAT("Time: ", NOW());
END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_covid_quarantine_followup$$
CREATE PROCEDURE sp_populate_etl_covid_quarantine_followup()
	BEGIN
		SELECT "Processing Covid quarantine followup ", CONCAT("Time: ", NOW());
-- -------------populate etl_covid_quarantine_followup-------------------------
INSERT INTO kenyaemr_etl.etl_covid_quarantine_followup(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
sub_county,
county,
fever,
cough,
difficulty_breathing,
sore_throat,
referred_to_hosp,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=161551,o.value_text,null)) as sub_county,
	max(if(o.concept_id=165197,o.value_text,null)) as county,
	max(if(o.concept_id=140238,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as fever,
	max(if(o.concept_id=143264,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as cough,
	max(if(o.concept_id=164441,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as diffiulty_breathing,
	max(if(o.concept_id=162737,(case o.value_coded when 158843 then "Yes" when 1066 then "No" else "" end),null)) as sore_throat,
	max(if(o.concept_id=1788,(case o.value_coded when 140238 then "Yes" when 1066 then "No" when 1175 then "N/A" else "" end),null)) as referred_to_hosp,
  	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('37ef8f3c-6cd2-11ea-bc55-0242ac130003')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
													 and o.concept_id in (161551,165197,140238,143264,164441,162737,1788)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 quarantine followup data ", CONCAT("Time: ", NOW());
END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_covid_quarantine_outcome$$
CREATE PROCEDURE sp_populate_etl_covid_quarantine_outcome()
	BEGIN
		SELECT "Processing Covid quarantine outcome", CONCAT("Time: ", NOW());
-- -------------populate etl_covid_quarantine_outcome-------------------------
INSERT INTO kenyaemr_etl.etl_covid_quarantine_outcome(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
discontinuation_reason,
transfer_to_facility,
comment,
referral_reason,
facility_referred_to,
discharge_reason,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=161555,(case o.value_coded when 159492 then "Transferred out" when 164165 then "Referral" when 1692 then "Discharged" else "" end),null)) as discontinuation_reason,
	max(if(o.concept_id=159495,o.value_text,null)) as transfer_to_facility,
	max(if(o.concept_id=160632,o.value_text,null)) as comment,
	max(if(o.concept_id=159623,(case o.value_coded when 162747 then "Cormobidity management" when 1185 then "Covid treatment" else "" end),null)) as referral_reason,
	max(if(o.concept_id=161562,o.value_text,null)) as facility_referred_to,
	max(if(o.concept_id=160433,(case o.value_coded when 126311 then "Home quarantine" when 1855 then "End of quarantine" else "" end),null)) as discharge_reason,
  	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join patient_program pp on pp.patient_id = e.patient_id and date(e.encounter_datetime) = date(pp.date_enrolled) and pp.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('9a5d58c4-739a-11ea-bc55-0242ac130003')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
													 and o.concept_id in (161555,159495,160632,159623,161562,160433)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 quarantine followup data ", CONCAT("Time: ", NOW());
END$$

DROP PROCEDURE IF EXISTS sp_populate_etl_covid_travel_history$$
CREATE PROCEDURE sp_populate_etl_covid_travel_history()
	BEGIN
		SELECT "Processing Covid Travel history", CONCAT("Time: ", NOW());
-- -------------populate etl_covid_travel_history-------------------------
INSERT INTO kenyaemr_etl.etl_covid_travel_history(
uuid,
encounter_id,
visit_id,
patient_id,
location_id,
visit_date,
encounter_provider,
date_created,
date_arrived_in_kenya,
mode_of_transport,
flight_bus_number,
seat_number,
country_visited,
destination_in_kenya,
name_of_contact_person,
phone_of_contact_person,
county,
sublocation_estate,
village_house_no_hotel,
address,
local_phone_number,
email,
fever,
cough,
difficulty_breathing,
voided
)
select
	e.uuid,
	e.encounter_id as encounter_id,
	e.visit_id as visit_id,
	e.patient_id,
	e.location_id,
	date(e.encounter_datetime) as visit_date,
	e.creator as encounter_provider,
	e.date_created as date_created,
	max(if(o.concept_id=160753,o.value_datetime,null)) as date_arrived_in_kenya,
	max(if(o.concept_id=1375,(case o.value_coded when 1378 then "Airline" when 1787 then "Bus" else "" end),null)) as mode_of_transport,
	max(if(o.concept_id=162612,o.value_text,null)) as flight_bus_number,
	max(if(o.concept_id=162086,o.value_text,null)) as seat_number,
	max(if(o.concept_id=165198,o.value_text,null)) as country_visited,
	max(if(o.concept_id=161550,o.value_text,null)) as destination_in_kenya,
	max(if(o.concept_id=163258,o.value_text,null)) as name_of_contact_person,
	max(if(o.concept_id=159635,o.value_text,null)) as phone_of_contact_person,
	max(if(o.concept_id=165197,o.value_text,null)) as county,
	max(if(o.concept_id=161551,o.value_text,null)) as sublocation_estate,
	max(if(o.concept_id=1354,o.value_text,null)) as village_house_no_hotel,
	max(if(o.concept_id=162725,o.value_text,null)) as address,
	max(if(o.concept_id=163152,o.value_text,null)) as local_phone_number,
	max(if(o.concept_id=160632,o.value_text,null)) as email,
	max(if(o.concept_id=140238,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as fever,
	max(if(o.concept_id=143264,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as cough,
	max(if(o.concept_id=164441,(case o.value_coded when 1065 then "Yes" when 1066 then "No" else "" end),null)) as difficulty_breathing,
  	e.voided as voided
from encounter e
	inner join person p on p.person_id=e.patient_id and p.voided=0
	inner join
	(
		select form_id, uuid,name from form where
			uuid in('87513b50-6ced-11ea-bc55-0242ac130003')
	) f on f.form_id=e.form_id
	left outer join obs o on o.encounter_id=e.encounter_id and o.voided=0
													 and o.concept_id in (160753,1375,162612,162086,165198,161550,163258,159635,165197,161551,1354,162725,163152,160632,140238,143264,164441)
where e.voided=0
group by e.patient_id, e.encounter_id, visit_date;

		SELECT "Completed processing covid_19 quarantine followup data ", CONCAT("Time: ", NOW());
END$$
		-- end of dml procedures

		SET sql_mode=@OLD_SQL_MODE$$

-- ------------------------------------------- running all procedures -----------------------------

DROP PROCEDURE IF EXISTS sp_first_time_setup$$
CREATE PROCEDURE sp_first_time_setup()
BEGIN
DECLARE populate_script_id INT(11);
SELECT "Beginning first time setup", CONCAT("Time: ", NOW());
INSERT INTO kenyaemr_etl.etl_script_status(script_name, start_time) VALUES('initial_population_of_tables', NOW());
SET populate_script_id = LAST_INSERT_ID();

CALL sp_populate_etl_patient_demographics();
CALL sp_populate_etl_laboratory_extract();
CALL sp_populate_etl_patient_program_discontinuation();
CALL sp_populate_etl_patient_program();
CALL sp_populate_etl_person_address();
CALL sp_populate_etl_patient_contact();
CALL sp_populate_etl_client_trace();
CALL sp_populate_etl_covid_19_enrolment();
CALL sp_populate_etl_contact_tracing_followup();
CALL sp_populate_etl_covid_quarantine_enrolment();
CALL sp_populate_etl_covid_quarantine_followup();
CALL sp_populate_etl_covid_quarantine_outcome();
CALL sp_populate_etl_covid_travel_history();

UPDATE kenyaemr_etl.etl_script_status SET stop_time=NOW() where id= populate_script_id;

SELECT "Completed first time setup", CONCAT("Time: ", NOW());
END$$



