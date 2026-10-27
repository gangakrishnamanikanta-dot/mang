-- ── Migration: Seed 100 Pan-Indian Brahmin Profiles & Preferences ─────────────
--
-- Inserts 100 realistic, authentic Pan-Indian Brahmin profiles (50 Male, 50 Female)
-- spanning Telugu, Tamil, Kannada, Marathi, North Indian, Gujarati, Saraswat, and Eastern communities.
-- Includes complete demographic, gothram, astrological, education, occupation, and partner preferences.

DO $$
DECLARE
    v_user_id uuid;
    i int;
    
    -- Names (50 Male, 50 Female)
    m_names text[] := ARRAY[
        'Aditya Sharma', 'Karthik Iyer', 'Venkatesh Rao', 'Anirudh Kulkarni', 'Siddharth Joshi',
        'Raghavan Iyengar', 'Abhishek Shastri', 'Pranav Deshpande', 'Srinivas Murthy', 'Chaitanya Dikshit',
        'Sai Krishna Nori', 'Vikramaditya Bhat', 'Gautam Upadhyay', 'Varun Chitpavan', 'Rohan GSB',
        'Harsha Vardhan Sastry', 'Madhav Namboothiri', 'Nikhil Karhade', 'Prashant Tiwari', 'Manoj Nagar',
        'Arunachalam Sundaram', 'Srikant Velanadu', 'Deepak Dwivedi', 'Kiran Havyaka', 'Tejas Audichya',
        'Shravan Kumar Shukla', 'Vishnuvardhan Ayyar', 'Sanjay Bhattacharya', 'Kishore Somayaji', 'Alok Mishra',
        'Rohit Dandavate', 'Swaroop Kaundinya', 'Sanket Agnihotri', 'Ramanuja Chari', 'Naveen Shivalli',
        'Tarun Mukherjee', 'Ajay Kashyap', 'Pramod Chaturvedi', 'Subhashish Panda', 'Vijayendra Theertha',
        'Manikanta Vasishta', 'Dinesh Pathak', 'Balaji Vadakalai', 'Sudarshan Tripathy', 'Anand Khedawal',
        'Girish Karve', 'Chinmay Purohit', 'Shripad Gokhale', 'Udayan Goswami', 'Vamshi Krishna Potti'
    ];

    f_names text[] := ARRAY[
        'Ananya Sharma', 'Sowmya Iyer', 'Deepika Rao', 'Pooja Kulkarni', 'Tanvi Joshi',
        'Vaishnavi Iyengar', 'Radhika Shastri', 'Shruti Deshpande', 'Aparna Murthy', 'Gayatri Dikshit',
        'Srilakshmi Nori', 'Kavya Bhat', 'Shreya Upadhyay', 'Meera Chitpavan', 'Divya GSB',
        'Harini Sastry', 'Lakshmi Namboothiri', 'Sneha Karhade', 'Priyanka Tiwari', 'Nandini Nagar',
        'Janaki Sundaram', 'Padmavathi Velanadu', 'Swati Dwivedi', 'Bhavana Havyaka', 'Ritu Audichya',
        'Pallavi Shukla', 'Shobhana Ayyar', 'Debolina Bhattacharya', 'Sandhya Somayaji', 'Archana Mishra',
        'Mrunal Dandavate', 'Kalyani Kaundinya', 'Ketaki Agnihotri', 'Vedavathi Chari', 'Pavitra Shivalli',
        'Madhurima Mukherjee', 'Samhita Kashyap', 'Ritika Chaturvedi', 'Suchitra Panda', 'Hemalatha Theertha',
        'Vandana Vasishta', 'Preeti Pathak', 'Mythili Vadakalai', 'Pracheeti Tripathy', 'Komal Khedawal',
        'Manasi Karve', 'Smita Purohit', 'Sanika Gokhale', 'Sharmistha Goswami', 'Lavanya Potti'
    ];

    -- Regional Brahmin Communities & Subcastes
    castes_arr int[] := ARRAY[
        3, 1, 2, 7, 6, 10, 11, 4, 5, 8, 9, 13, 14, 15, 18, 19, 20, 21, 24, 25, 31, 27
    ];
    
    subcastes_arr text[] := ARRAY[
        'Vaidiki Velanadu', 'Niyogi Aruvela', 'Iyer Vadama', 'Iyengar Vadakalai', 'Iyengar Thenkalai',
        'Deshastha Rigvedi', 'Chitpavan Kokanastha', 'Smartha Hoysala', 'Madhwa Shivalli', 'Havyaka',
        'Goud Saraswat (GSB)', 'Chitrapur Saraswat', 'Kanyakubja', 'Saryupareen', 'Gaur Brahmin',
        'Nagar Brahmin', 'Audichya Sahasra', 'Bengali Rarhi', 'Odia Utkala', 'Karhade Brahmin',
        'Dravida Brahmin', 'Telaganya Brahmin'
    ];

    -- Locations
    cities_arr text[] := ARRAY[
        'Hyderabad', 'Bengaluru', 'Chennai', 'Mumbai', 'Pune', 'New Delhi', 'Visakhapatnam',
        'Vijayawada', 'Kolkata', 'Ahmedabad', 'Dallas, TX', 'San Jose, CA', 'Seattle, WA'
    ];
    states_arr text[] := ARRAY[
        'Telangana', 'Karnataka', 'Tamil Nadu', 'Maharashtra', 'Maharashtra', 'Delhi', 'Andhra Pradesh',
        'Andhra Pradesh', 'West Bengal', 'Gujarat', 'Texas, USA', 'California, USA', 'Washington, USA'
    ];

    -- Colleges & Companies
    colleges_arr text[] := ARRAY[
        'IIT Madras', 'IIT Bombay', 'BITS Pilani', 'IISc Bangalore', 'NIT Warangal',
        'Osmania Medical College', 'IIM Ahmedabad', 'ISB Hyderabad', 'Stanford University', 'CMU'
    ];
    companies_arr text[] := ARRAY[
        'Google', 'Microsoft', 'Amazon', 'Apple', 'Deloitte', 'Goldman Sachs', 'Apollo Hospitals',
        'TCS', 'Infosys', 'McKinsey & Co'
    ];

    -- Photo URLs
    m_photos text[] := ARRAY[
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=500&auto=format&fit=crop'
    ];

    f_photos text[] := ARRAY[
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=500&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop'
    ];

    v_caste_id int;
    v_sub_caste text;
    v_gothram_id int;
    v_nakshatra_id int;
    v_rashi_id int;
    v_tongue_id int;
    v_edu_id int;
    v_occ_id int;
    v_income_id int;
    v_loc_idx int;
    v_dob date;
    v_height int;
    v_photo text;
    v_bio text;
BEGIN
    -- ── 1. INSERT 50 MALE PROFILES ───────────────────────────────────────────
    FOR i IN 1..50 LOOP
        v_user_id := ('b0000000-0000-0000-0001-' || LPAD(i::text, 12, '0'))::uuid;
        v_caste_id := castes_arr[1 + (i % array_length(castes_arr, 1))];
        v_sub_caste := subcastes_arr[1 + (i % array_length(subcastes_arr, 1))];
        v_gothram_id := 1 + (i % 25);
        v_nakshatra_id := 1 + (i % 27);
        v_rashi_id := 1 + (i % 12);
        v_tongue_id := CASE 
            WHEN v_caste_id IN (1, 2) THEN 1   -- Tamil
            WHEN v_caste_id IN (3, 10) THEN 2  -- Telugu
            WHEN v_caste_id IN (11, 14, 15) THEN 3 -- Kannada
            WHEN v_caste_id IN (6, 7, 8, 9, 27) THEN 6 -- Marathi
            WHEN v_caste_id IN (4, 5) THEN 12  -- Konkani
            WHEN v_caste_id IN (24, 25) THEN 7 -- Gujarati
            WHEN v_caste_id IN (20) THEN 8     -- Bengali
            WHEN v_caste_id IN (31) THEN 10    -- Odia
            ELSE 5                             -- Hindi
        END;
        v_edu_id := 1 + (i % 10);
        v_occ_id := 1 + (i % 15);
        v_income_id := 4 + (i % 8);
        v_loc_idx := 1 + (i % array_length(cities_arr, 1));
        v_dob := (CURRENT_DATE - ((25 + (i % 10)) * INTERVAL '1 year' + ((i * 7) % 365) * INTERVAL '1 day'))::date;
        v_height := 66 + (i % 10);
        v_photo := m_photos[1 + (i % array_length(m_photos, 1))];
        v_bio := 'Traditional Brahmin professional with deep cultural roots. Enjoys Carnatic music, travel, and fitness.';

        -- Create in auth.users
        INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
        VALUES (
            v_user_id,
            '00000000-0000-0000-0000-000000000000',
            'authenticated',
            'authenticated',
            'test_male_' || i || '@mangalasutram.com',
            crypt('Password@123', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', m_names[i]),
            now(),
            now()
        )
        ON CONFLICT (id) DO NOTHING;

        -- Create/Update in profiles
        INSERT INTO public.profiles (
            id, email, full_name, gender, date_of_birth, height_inches, marital_status_id,
            mother_tongue_id, caste_id, sub_caste, gothram_id, nakshatra_id, rashi_id,
            highest_education_id, college, occupation_id, company, annual_income_id,
            city, state, work_location, profile_photo_url, about_me, food_preference_id,
            kuja_dosham, is_verified, created_for, created_at, updated_at
        ) VALUES (
            v_user_id, 'test_male_' || i || '@mangalasutram.com', m_names[i], 'Male', v_dob, v_height, 1,
            v_tongue_id, v_caste_id, v_sub_caste, v_gothram_id, v_nakshatra_id, v_rashi_id,
            v_edu_id, colleges_arr[1 + (i % array_length(colleges_arr, 1))],
            v_occ_id, companies_arr[1 + (i % array_length(companies_arr, 1))],
            v_income_id, cities_arr[v_loc_idx], states_arr[v_loc_idx], cities_arr[v_loc_idx],
            v_photo, v_bio, 1, 'No', (i % 2 = 0), 'Self', now() - (i || ' days')::interval, now()
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            gender = EXCLUDED.gender,
            date_of_birth = EXCLUDED.date_of_birth,
            height_inches = EXCLUDED.height_inches,
            marital_status_id = EXCLUDED.marital_status_id,
            mother_tongue_id = EXCLUDED.mother_tongue_id,
            caste_id = EXCLUDED.caste_id,
            sub_caste = EXCLUDED.sub_caste,
            gothram_id = EXCLUDED.gothram_id,
            nakshatra_id = EXCLUDED.nakshatra_id,
            rashi_id = EXCLUDED.rashi_id,
            highest_education_id = EXCLUDED.highest_education_id,
            college = EXCLUDED.college,
            occupation_id = EXCLUDED.occupation_id,
            company = EXCLUDED.company,
            annual_income_id = EXCLUDED.annual_income_id,
            city = EXCLUDED.city,
            state = EXCLUDED.state,
            work_location = EXCLUDED.work_location,
            profile_photo_url = EXCLUDED.profile_photo_url,
            about_me = EXCLUDED.about_me,
            food_preference_id = EXCLUDED.food_preference_id,
            kuja_dosham = EXCLUDED.kuja_dosham,
            is_verified = EXCLUDED.is_verified,
            created_for = EXCLUDED.created_for;

        -- Create partner preferences
        INSERT INTO public.partner_preferences (
            profile_id, min_age, max_age, min_height_inches, max_height_inches,
            preferred_caste_ids, preferred_marital_status_ids, preferred_mother_tongue_ids,
            exclude_same_gotra, kuja_dosham_preference, created_at, updated_at
        ) VALUES (
            v_user_id,
            EXTRACT(YEAR FROM age(v_dob))::int - 5,
            EXTRACT(YEAR FROM age(v_dob))::int + 1,
            v_height - 8,
            v_height,
            ARRAY[v_caste_id, 3],
            ARRAY[1],
            ARRAY[v_tongue_id],
            true,
            'No',
            now(),
            now()
        )
        ON CONFLICT (profile_id) DO UPDATE SET
            min_age = EXCLUDED.min_age,
            max_age = EXCLUDED.max_age,
            min_height_inches = EXCLUDED.min_height_inches,
            max_height_inches = EXCLUDED.max_height_inches,
            preferred_caste_ids = EXCLUDED.preferred_caste_ids,
            exclude_same_gotra = EXCLUDED.exclude_same_gotra;
    END LOOP;

    -- ── 2. INSERT 50 FEMALE PROFILES ─────────────────────────────────────────
    FOR i IN 1..50 LOOP
        v_user_id := ('b0000000-0000-0000-0002-' || LPAD(i::text, 12, '0'))::uuid;
        v_caste_id := castes_arr[1 + (i % array_length(castes_arr, 1))];
        v_sub_caste := subcastes_arr[1 + (i % array_length(subcastes_arr, 1))];
        v_gothram_id := 1 + ((i + 7) % 25);
        v_nakshatra_id := 1 + ((i + 5) % 27);
        v_rashi_id := 1 + ((i + 3) % 12);
        v_tongue_id := CASE 
            WHEN v_caste_id IN (1, 2) THEN 1
            WHEN v_caste_id IN (3, 10) THEN 2
            WHEN v_caste_id IN (11, 14, 15) THEN 3
            WHEN v_caste_id IN (6, 7, 8, 9, 27) THEN 6
            WHEN v_caste_id IN (4, 5) THEN 12
            WHEN v_caste_id IN (24, 25) THEN 7
            WHEN v_caste_id IN (20) THEN 8
            WHEN v_caste_id IN (31) THEN 10
            ELSE 5
        END;
        v_edu_id := 1 + (i % 10);
        v_occ_id := 1 + (i % 15);
        v_income_id := 3 + (i % 8);
        v_loc_idx := 1 + ((i + 3) % array_length(cities_arr, 1));
        v_dob := (CURRENT_DATE - ((23 + (i % 8)) * INTERVAL '1 year' + ((i * 11) % 365) * INTERVAL '1 day'))::date;
        v_height := 61 + (i % 8);
        v_photo := f_photos[1 + (i % array_length(f_photos, 1))];
        v_bio := 'Well-educated, family-oriented Brahmin professional. Passionate about arts, Indian heritage, and reading.';

        -- Create in auth.users
        INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
        VALUES (
            v_user_id,
            '00000000-0000-0000-0000-000000000000',
            'authenticated',
            'authenticated',
            'test_female_' || i || '@mangalasutram.com',
            crypt('Password@123', gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', f_names[i]),
            now(),
            now()
        )
        ON CONFLICT (id) DO NOTHING;

        -- Create/Update in profiles
        INSERT INTO public.profiles (
            id, email, full_name, gender, date_of_birth, height_inches, marital_status_id,
            mother_tongue_id, caste_id, sub_caste, gothram_id, nakshatra_id, rashi_id,
            highest_education_id, college, occupation_id, company, annual_income_id,
            city, state, work_location, profile_photo_url, about_me, food_preference_id,
            kuja_dosham, is_verified, created_for, created_at, updated_at
        ) VALUES (
            v_user_id, 'test_female_' || i || '@mangalasutram.com', f_names[i], 'Female', v_dob, v_height, 1,
            v_tongue_id, v_caste_id, v_sub_caste, v_gothram_id, v_nakshatra_id, v_rashi_id,
            v_edu_id, colleges_arr[1 + ((i + 2) % array_length(colleges_arr, 1))],
            v_occ_id, companies_arr[1 + ((i + 2) % array_length(companies_arr, 1))],
            v_income_id, cities_arr[v_loc_idx], states_arr[v_loc_idx], cities_arr[v_loc_idx],
            v_photo, v_bio, 1, 'No', (i % 2 = 1), 'Self', now() - (i || ' days')::interval, now()
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            gender = EXCLUDED.gender,
            date_of_birth = EXCLUDED.date_of_birth,
            height_inches = EXCLUDED.height_inches,
            marital_status_id = EXCLUDED.marital_status_id,
            mother_tongue_id = EXCLUDED.mother_tongue_id,
            caste_id = EXCLUDED.caste_id,
            sub_caste = EXCLUDED.sub_caste,
            gothram_id = EXCLUDED.gothram_id,
            nakshatra_id = EXCLUDED.nakshatra_id,
            rashi_id = EXCLUDED.rashi_id,
            highest_education_id = EXCLUDED.highest_education_id,
            college = EXCLUDED.college,
            occupation_id = EXCLUDED.occupation_id,
            company = EXCLUDED.company,
            annual_income_id = EXCLUDED.annual_income_id,
            city = EXCLUDED.city,
            state = EXCLUDED.state,
            work_location = EXCLUDED.work_location,
            profile_photo_url = EXCLUDED.profile_photo_url,
            about_me = EXCLUDED.about_me,
            food_preference_id = EXCLUDED.food_preference_id,
            kuja_dosham = EXCLUDED.kuja_dosham,
            is_verified = EXCLUDED.is_verified,
            created_for = EXCLUDED.created_for;

        -- Create partner preferences
        INSERT INTO public.partner_preferences (
            profile_id, min_age, max_age, min_height_inches, max_height_inches,
            preferred_caste_ids, preferred_marital_status_ids, preferred_mother_tongue_ids,
            exclude_same_gotra, kuja_dosham_preference, created_at, updated_at
        ) VALUES (
            v_user_id,
            EXTRACT(YEAR FROM age(v_dob))::int - 1,
            EXTRACT(YEAR FROM age(v_dob))::int + 6,
            v_height,
            v_height + 10,
            ARRAY[v_caste_id, 3],
            ARRAY[1],
            ARRAY[v_tongue_id],
            true,
            'No',
            now(),
            now()
        )
        ON CONFLICT (profile_id) DO UPDATE SET
            min_age = EXCLUDED.min_age,
            max_age = EXCLUDED.max_age,
            min_height_inches = EXCLUDED.min_height_inches,
            max_height_inches = EXCLUDED.max_height_inches,
            preferred_caste_ids = EXCLUDED.preferred_caste_ids,
            exclude_same_gotra = EXCLUDED.exclude_same_gotra;
    END LOOP;
END;
$$;
