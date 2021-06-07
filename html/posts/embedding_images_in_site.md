# Embed photos from S3 in website

This post is part 3 in a series of posts where I am documenting how I built this 
site - via trial and error. Some good practices, some bad. But always learning more 
and more. These posts follow a mixed style - conversational at times, instructional at 
others. Drop me a message if you have questions/feedbacks about any of these posts.

In the [last post](https://www.a93.in/posts/cgi_setup.html) I discussed setting up 
CGI (Common Gateway Interface) scripts on the server to capture user's messages, 
stuff them in a DynamoDB table, send an email notification and then redirect the user 
to the homepage.

In this post I am going to discuss adding images to our website. These images are 
stored in the S3 bucket and I would like to *not* provide public access to my 
bucket or download these images to the server for long term storage (because that 
defeats the purpose of using S3 as object storage). I will be discussing three 
methods to do (some)what I want and then in the end we will make our choice. Just know 
this: if there are images on this page they are being embedded here using the method 
that we will choose at the end :)

You can learn more about [AWS](), [S3 buckets](), [how to create S3 buckets]() 
and the [security best practices for S3]()  by following these links.

## Bucket allows access based on referrer
We will start by *disabling* the `Block all public access` setting of the S3 bucket (
yes, I know that is bad but still just for sake of completeness. We will revert those 
settings in the end). Once the settings are disabled, add the 
following policy to allow access to the bucket only when the referer is 
our domain. This is what the policy looks like:

```
{
    "Version": "2012-10-17",
    "Id": "limit access to a93.in domain",
    "Statement": [
        {
            "Sid": "a93.in",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::bucketname/*",
            "Condition": {
                "StringLike": {
                    "aws:Referer": "https://a93.in/*"
                }
            }
        }
    ]
}
```

The above policy statement allows us to restrict the access only to the requests 
that originate from the domain "https://a93.in" and to a specific bucket called 
"bucketname" (which is a placeholder name, replace it with the name of the bucket 
to which it is attached and do the same with the domain name as well).

Once that policy is attached, turn on all the block public access settings *except* 
for the one that says "Block public and cross-account access to buckets and 
objects through any public bucket or access point policies". 

Upload an image to the bucket, get its object URL and try to download it from an 
incognito window. You should get an Access Denied error with response code of 403. 
But if you embed it in a document (page) in your webserver, it will load 
properly. It looks like the desired behaviour but there are two problems with this:

1. We have a bucket with public access and,
2. Even though it looks like we have restricted access but in actuality we haven't

Take a look at this screenshot:

![screenshot of a webpage showing a screenshot of Mozilla reference document](
https://a93-in.s3.amazonaws.com/posts/embedding_image_in_sites/referer_header_1.png "Look... it
works")

This is a screenshot of a webpage showing an image containing a screenshot of a Mozilla 
document. If you open the developer tools of your browser and navigate to the 'Network' 
section you can see the headers sent with the request for that image. It contains a header 
called 'Referer'. Now, copy the headers and use curl to make a request using the 
same set of headers, like this:

```
curl \
-H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0" \
-H "Accept: image/webp,*/*" \ 
-H "Accept-Language: en-US,en;q=0.5" \ 
-H "Accept-Encoding: gzip, deflate, br" \ 
-H "Connection: keep-alive" \
-H "Referer: https://www.a93.in/" \ 
-H "Cache-Control: max-age=0" \
-X GET *****.s3.amazonaws.com/images/screen.png \
-o screenshot.png
```
 
This request should download the image to a file named screenshot.png (copy pasting the 
above curl request won't work). Now if it works with one request 
and we know how to write a loop, then we have what we didn't want to happen, like this:

```
download_image(name) {
 // put the curl command here
}

for i in `seq 1 100`; do download_image $i; done 
```

Here we put the curl request in a function and replace the output name with a 
variable name (that is being provided as the parameter) and then we are calling 
it from within a for loop - which will download it 100 times. 

So, in conclusion, it is not what we are looking for.

## Images cached on the server

## Pre-signed URL

