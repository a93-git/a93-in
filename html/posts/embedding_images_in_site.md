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

## Bucket allows access based on referrer

## Images cached on the server

## Pre-signed URL
