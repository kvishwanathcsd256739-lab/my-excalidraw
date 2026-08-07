const fs = require('fs');
const path = require('path');

const guideDir = path.join(__dirname, 'learning-guide');
const files = [
  '00-index.md',
  '01-big-picture-and-aws.md',
  '02-servers-ec2-linux.md',
  '03-git-docker.md',
  '04-nginx-dns-ssl.md',
  '05-deployment-and-mistakes.md',
  '06-mental-models-and-diagrams.md',
  '07-roadmap-and-vocabulary.md',
  '08-interview-prep.md',
  '09-industry-and-reflection.md'
];

let mergedMarkdown = '';

files.forEach((file, index) => {
  const filePath = path.join(guideDir, file);
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    return;
  }
  
  let content = fs.readFileSync(filePath, 'utf8');

  // Remove individual file navigation links like [Back to Index] or Next Step: Proceed to ...
  content = content.replace(/\[Back to Index\]\(.*?\)\n*/g, '');
  content = content.replace(/Next Step: Proceed to \*\*\[.*?\]\(.*?\)\*\* to .*?\n*/g, '');
  content = content.trim();

  if (index > 0) {
    mergedMarkdown += '\n\n---\n\n';
  }
  mergedMarkdown += content;
});

const mergedPath = path.join(guideDir, 'Excalidraw_AWS_Cloud_Engineering_Guide.md');
fs.writeFileSync(mergedPath, mergedMarkdown, 'utf8');
console.log(`Successfully merged ${files.length} modules into: ${mergedPath}`);
