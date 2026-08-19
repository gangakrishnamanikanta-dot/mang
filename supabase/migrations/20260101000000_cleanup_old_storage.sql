-- Drop duplicate policies tied to the old 'profile-photos' bucket
drop policy if exists "delete_own yndkpx_0" on storage.objects;
drop policy if exists "delete_own yndkpx_1" on storage.objects;
drop policy if exists "public_view yndkpx_0" on storage.objects;
drop policy if exists "update_own yndkpx_0" on storage.objects;
drop policy if exists "update_own yndkpx_1" on storage.objects;
drop policy if exists "upload_own yndkpx_0" on storage.objects;
drop policy if exists "upload_own yndkpx_1" on storage.objects;

-- Make the empty old bucket private so it can't be used
update storage.buckets set public = false where id = 'profile-photos';