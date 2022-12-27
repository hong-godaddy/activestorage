# Active Storage

# Reamaze's ActiveStorage

Reamaze keeps a fork of ActiveStorage for easy integration with our Rails application.

## Reasons For Changes

### `ActiveStorage::AnalyzeJob`

If `MiniMagick` encountered an error, say a corrupt or empty image, the
`AnalyzeJob` would fail and retry many times rather uselessly.

### `ActiveStorage::Attachment`

Because our models (namely `Login` and `Attachment`) have bigint `id`s and uuid `uuid`s, we needed a way to specify the `uuid` as the primary key for the association. This can be removed once/if we rename the `uuid` columns of `Login` and `Attachment` to be `id`.

### `ActiveStorage::Attached::Model`

Because our models (namely `Login` and `Attachment`) have bigint `id`s and uuid `uuid`s, we needed a way to specify the `uuid` as the primary key for the association. This can be removed once/if we rename the `uuid` columns of `Login` and `Attachment` to be `id`.

## Diff Between Upstream 7-0-stable

(diff to README.md omitted because of recursion)

```diff
--- a/activestorage/activestorage.gemspec
+++ b/activestorage/activestorage.gemspec
@@ -1,6 +1,6 @@
 # frozen_string_literal: true
 
-version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip
+version = '7.0.3'
 
 Gem::Specification.new do |s|
   s.platform    = Gem::Platform::RUBY
@@ -21,11 +21,11 @@ Gem::Specification.new do |s|
   s.require_path = "lib"
 
   s.metadata = {
-    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
-    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/activestorage/CHANGELOG.md",
+    "bug_tracker_uri"   => "https://github.com/jyoun-godaddy/activestorage/issues",
+    "changelog_uri"     => "https://github.com/jyoun-godaddy/activestorage/blob/v#{version}/activestorage/CHANGELOG.md",
     "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
     "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
-    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/activestorage",
+    "source_code_uri"   => "https://github.com/jyoun-godaddy/activestorage/tree/v#{version}/activestorage",
     "rubygems_mfa_required" => "true",
   }
 
diff --git a/activestorage/app/jobs/active_storage/analyze_job.rb b/activestorage/app/jobs/active_storage/analyze_job.rb
index 890781d..c5f2d0c 100644
--- a/activestorage/app/jobs/active_storage/analyze_job.rb
+++ b/activestorage/app/jobs/active_storage/analyze_job.rb
@@ -4,7 +4,7 @@
 class ActiveStorage::AnalyzeJob < ActiveStorage::BaseJob
   queue_as { ActiveStorage.queues[:analysis] }
 
-  discard_on ActiveRecord::RecordNotFound
+  discard_on ActiveRecord::RecordNotFound, MiniMagick::Error
   retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :exponentially_longer
 
   def perform(blob)
diff --git a/activestorage/app/models/active_storage/attachment.rb b/activestorage/app/models/active_storage/attachment.rb
index ed69dcc..4201565 100644
--- a/activestorage/app/models/active_storage/attachment.rb
+++ b/activestorage/app/models/active_storage/attachment.rb
@@ -10,7 +10,7 @@ require "active_support/core_ext/module/delegation"
 class ActiveStorage::Attachment < ActiveStorage::Record
   self.table_name = "active_storage_attachments"
 
-  belongs_to :record, polymorphic: true, touch: true
+  belongs_to :record, polymorphic: true, touch: true, primary_key: :uuid
   belongs_to :blob, class_name: "ActiveStorage::Blob", autosave: true
 
   delegate_missing_to :blob
diff --git a/activestorage/app/models/active_storage/blob.rb b/activestorage/app/models/active_storage/blob.rb
index fba4bb6..10c401f 100644
--- a/activestorage/app/models/active_storage/blob.rb
+++ b/activestorage/app/models/active_storage/blob.rb
@@ -68,6 +68,9 @@ class ActiveStorage::Blob < ActiveStorage::Record
     end
   end
 
+  alias_method :uuid, :id
+
   class << self
     # You can use the signed ID of a blob to refer to it on the client side without fear of tampering.
     # This is particularly helpful for direct uploads where the client-side needs to refer to the blob
diff --git a/activestorage/lib/active_storage/attached/model.rb b/activestorage/lib/active_storage/attached/model.rb
index 85ddbb8..82c7036 100644
--- a/activestorage/lib/active_storage/attached/model.rb
+++ b/activestorage/lib/active_storage/attached/model.rb
@@ -67,7 +67,7 @@ module ActiveStorage
           end
         CODE
 
-        has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
+        has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy, strict_loading: strict_loading, primary_key: :uuid
         has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading
 
         scope :"with_attached_#{name}", -> { includes("#{name}_attachment": :blob) }
@@ -152,7 +152,7 @@ module ActiveStorage
           end
         CODE
 
-        has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy, strict_loading: strict_loading do
+        has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy, strict_loading: strict_loading, primary_key: :uuid do
           def purge
             each(&:purge)
             reset
             --- a/activestorage/lib/active_storage/downloader.rb

diff --git a/activestorage/lib/active_storage/downloader.rb b/activestorage/lib/active_storage/downloader.rb
+++ b/activestorage/lib/active_storage/downloader.rb
@@ -11,7 +11,7 @@ module ActiveStorage
     def open(key, checksum:, name: "ActiveStorage-", tmpdir: nil)
       open_tempfile(name, tmpdir) do |file|
         download key, file
-        verify_integrity_of(file, checksum: checksum) if verify
+        verify_integrity_of(file, checksum: checksum) if verify && !checksum.empty?
         yield file
       end
     end

diff --git a/activestorage/app/models/active_storage/variant_record.rb b/activestorage/app/models/active_storage/variant_record.rb
index 4f0d5a4309..fd40c774e0 100644
--- a/activestorage/app/models/active_storage/variant_record.rb
+++ b/activestorage/app/models/active_storage/variant_record.rb
@@ -4,7 +4,7 @@ class ActiveStorage::VariantRecord < ActiveStorage::Record
   self.table_name = "active_storage_variant_records"

+  alias_method :uuid, :id
+  belongs_to :blob, primary_key: :uuid

-  belongs_to :blob
   has_one_attached :image
 end
```

---

Active Storage makes it simple to upload and reference files in cloud services like [Amazon S3](https://aws.amazon.com/s3/), [Google Cloud Storage](https://cloud.google.com/storage/docs/), or [Microsoft Azure Storage](https://azure.microsoft.com/en-us/services/storage/), and attach those files to Active Records. Supports having one main service and mirrors in other services for redundancy. It also provides a disk service for testing or local deployments, but the focus is on cloud storage.

Files can be uploaded from the server to the cloud or directly from the client to the cloud.

Image files can furthermore be transformed using on-demand variants for quality, aspect ratio, size, or any other [MiniMagick](https://github.com/minimagick/minimagick) or [Vips](https://www.rubydoc.info/gems/ruby-vips/Vips/Image) supported transformation.

You can read more about Active Storage in the [Active Storage Overview](https://edgeguides.rubyonrails.org/active_storage_overview.html) guide.

## Compared to other storage solutions

A key difference to how Active Storage works compared to other attachment solutions in Rails is through the use of built-in [Blob](https://github.com/rails/rails/blob/main/activestorage/app/models/active_storage/blob.rb) and [Attachment](https://github.com/rails/rails/blob/main/activestorage/app/models/active_storage/attachment.rb) models (backed by Active Record). This means existing application models do not need to be modified with additional columns to associate with files. Active Storage uses polymorphic associations via the `Attachment` join model, which then connects to the actual `Blob`.

`Blob` models store attachment metadata (filename, content-type, etc.), and their identifier key in the storage service. Blob models do not store the actual binary data. They are intended to be immutable in spirit. One file, one blob. You can associate the same blob with multiple application models as well. And if you want to do transformations of a given `Blob`, the idea is that you'll simply create a new one, rather than attempt to mutate the existing one (though of course you can delete the previous version later if you don't need it).

## Installation

Run `bin/rails active_storage:install` to copy over active_storage migrations.

NOTE: If the task cannot be found, verify that `require "active_storage/engine"` is present in `config/application.rb`.

## Examples

One attachment:

```ruby
class User < ApplicationRecord
  # Associates an attachment and a blob. When the user is destroyed they are
  # purged by default (models destroyed, and resource files deleted).
  has_one_attached :avatar
end

# Attach an avatar to the user.
user.avatar.attach(io: File.open("/path/to/face.jpg"), filename: "face.jpg", content_type: "image/jpeg")

# Does the user have an avatar?
user.avatar.attached? # => true

# Synchronously destroy the avatar and actual resource files.
user.avatar.purge

# Destroy the associated models and actual resource files async, via Active Job.
user.avatar.purge_later

# Does the user have an avatar?
user.avatar.attached? # => false

# Generate a permanent URL for the blob that points to the application.
# Upon access, a redirect to the actual service endpoint is returned.
# This indirection decouples the public URL from the actual one, and
# allows for example mirroring attachments in different services for
# high-availability. The redirection has an HTTP expiration of 5 min.
url_for(user.avatar)

class AvatarsController < ApplicationController
  def update
    # params[:avatar] contains an ActionDispatch::Http::UploadedFile object
    Current.user.avatar.attach(params.require(:avatar))
    redirect_to Current.user
  end
end
```

Many attachments:

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

```erb
<%= form_with model: @message, local: true do |form| %>
  <%= form.text_field :title, placeholder: "Title" %><br>
  <%= form.text_area :content %><br><br>

  <%= form.file_field :images, multiple: true %><br>
  <%= form.submit %>
<% end %>
```

```ruby
class MessagesController < ApplicationController
  def index
    # Use the built-in with_attached_images scope to avoid N+1
    @messages = Message.all.with_attached_images
  end

  def create
    message = Message.create! params.require(:message).permit(:title, :content, images: [])
    redirect_to message
  end

  def show
    @message = Message.find(params[:id])
  end
end
```

Variation of image attachment:

```erb
<%# Hitting the variant URL will lazy transform the original blob and then redirect to its new service location %>
<%= image_tag user.avatar.variant(resize_to_limit: [100, 100]) %>
```

## File serving strategies

Active Storage supports two ways to serve files: redirecting and proxying.

### Redirecting

Active Storage generates stable application URLs for files which, when accessed, redirect to signed, short-lived service URLs. This relieves application servers of the burden of serving file data. It is the default file serving strategy.

When the application is configured to proxy files by default, use the `rails_storage_redirect_path` and `_url` route helpers to redirect instead:

```erb
<%= image_tag rails_storage_redirect_path(@user.avatar) %>
```

### Proxying

Optionally, files can be proxied instead. This means that your application servers will download file data from the storage service in response to requests. This can be useful for serving files from a CDN.

You can configure Active Storage to use proxying by default:

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

Or if you want to explicitly proxy specific attachments there are URL helpers you can use in the form of `rails_storage_proxy_path` and `rails_storage_proxy_url`.

```erb
<%= image_tag rails_storage_proxy_path(@user.avatar) %>
```

## Direct uploads

Active Storage, with its included JavaScript library, supports uploading directly from the client to the cloud.

### Direct upload installation

1. Include the Active Storage JavaScript in your application's JavaScript bundle or reference it directly.

    Requiring directly without bundling through the asset pipeline in the application html with autostart:
    ```html
    <%= javascript_include_tag "activestorage" %>
    ```
    Requiring via importmap-rails without bundling through the asset pipeline in the application html without autostart as ESM:
    ```ruby
    # config/importmap.rb
    pin "@rails/activestorage", to: "activestorage.esm.js"
    ```
    ```html
    <script type="module-shim">
      import * as ActiveStorage from "@rails/activestorage"
      ActiveStorage.start()
    </script>
    ```
    Using the asset pipeline:
    ```js
    //= require activestorage
    ```
    Using the npm package:
    ```js
    import * as ActiveStorage from "@rails/activestorage"
    ActiveStorage.start()
    ```
2. Annotate file inputs with the direct upload URL.

    ```ruby
    <%= form.file_field :attachments, multiple: true, direct_upload: true %>
    ```
3. That's it! Uploads begin upon form submission.

### Direct upload JavaScript events

| Event name | Event target | Event data (`event.detail`) | Description |
| --- | --- | --- | --- |
| `direct-uploads:start` | `<form>` | None | A form containing files for direct upload fields was submitted. |
| `direct-upload:initialize` | `<input>` | `{id, file}` | Dispatched for every file after form submission. |
| `direct-upload:start` | `<input>` | `{id, file}` | A direct upload is starting. |
| `direct-upload:before-blob-request` | `<input>` | `{id, file, xhr}` | Before making a request to your application for direct upload metadata. |
| `direct-upload:before-storage-request` | `<input>` | `{id, file, xhr}` | Before making a request to store a file. |
| `direct-upload:progress` | `<input>` | `{id, file, progress}` | As requests to store files progress. |
| `direct-upload:error` | `<input>` | `{id, file, error}` | An error occurred. An `alert` will display unless this event is canceled. |
| `direct-upload:end` | `<input>` | `{id, file}` | A direct upload has ended. |
| `direct-uploads:end` | `<form>` | None | All direct uploads have ended. |

## License

Active Storage is released under the [MIT License](https://opensource.org/licenses/MIT).

## Support

API documentation is at:

* https://api.rubyonrails.org

Bug reports for the Ruby on Rails project can be filed here:

* https://github.com/rails/rails/issues

Feature requests should be discussed on the rails-core mailing list here:

* https://discuss.rubyonrails.org/c/rubyonrails-core
