// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Bounded implementation of Kookit/foliate INDX's existing table/cncx contract.
export async function boundedIndexData(index,loadRecord) {
  const bytes=async i=>new Uint8Array(await loadRecord(i));
  const uint=(b,p,n=4)=>{if(p<0||p+n>b.length)throw Error('Truncated INDX');let v=0;for(let i=0;i<n;i++)v=v*256+b[p+i];return v;};
  const magic=(b,p,s)=>s.split('').every((c,i)=>b[p+i]===c.charCodeAt(0));
  const variable=(b,p,end)=>{let value=0;for(let n=0;n<4;n++){if(p+n>=end)throw Error('Truncated INDX integer');const x=b[p+n];value=value*128+(x&127);if(x&128){if(value>4194304)throw Error('INDX value budget');return {value,length:n+1};}}throw Error('INDX integer too long');};
  const master=await bytes(index),length=uint(master,4),records=uint(master,24),cncxRecords=uint(master,52);
  if(!magic(master,0,'INDX')||records>1000||cncxRecords>100||length<56||!magic(master,length,'TAGX'))throw Error('INDX header');
  const tagLength=uint(master,length+4),controls=uint(master,length+8);
  if(tagLength<12||tagLength>1024||tagLength%4||length+tagLength>master.length||controls<1||controls>8)throw Error('TAGX structure');
  const tags=[];for(let p=length+12;p<length+tagLength;p+=4){const t=Array.from(master.subarray(p,p+4));if(t[1]<1||t[1]>8||!t[2])throw Error('TAGX mask');tags.push(t);}
  const decoder=new TextDecoder(uint(master,28)===1252?'windows-1252':'utf-8',{fatal:true}),cncx=Object.create(null);
  for(let i=0;i<cncxRecords;i++){const b=await bytes(index+records+i+1);for(let p=0;p<b.length;){const start=p,v=variable(b,p,b.length);p+=v.length;if(p+v.value>b.length)throw Error('CNCX range');cncx[i*65536+start]=decoder.decode(b.subarray(p,p+v.value));p+=v.value;}}
  const table=[];
  for(let i=0;i<records;i++){
    const b=await bytes(index+i+1),idxt=uint(b,20),count=uint(b,24),header=uint(b,4);
    if(!magic(b,0,'INDX')||count>1000||idxt<header||!magic(b,idxt,'IDXT')||idxt+4+count*2>b.length)throw Error('IDXT structure');
    const offsets=Array.from({length:count},(_,j)=>uint(b,idxt+4+j*2,2));
    for(let j=0;j<count;j++){
      const offset=offsets[j],end=offsets[j+1]??idxt;
      if(offset<header||offset>=end||end>idxt)throw Error('INDX entry range');
      const nameLength=uint(b,offset,1),start=offset+1+nameLength;
      if(start+controls>end)throw Error('INDX control bytes');
      const name=decoder.decode(b.subarray(offset+1,start)),tagMap=Object.create(null);let p=start+controls,control=0;
      for(const [tag,numValues,mask,terminator] of tags){
        if(terminator&1){control++;continue;}if(control>=controls)throw Error('TAGX control range');
        const masked=b[start+control]&mask;let count=0,byteCount=null;
        if(masked===mask){if((mask&(mask-1))!==0){const v=variable(b,p,end);p+=v.length;byteCount=v.value;}else{const v=variable(b,p,end);p+=v.length;count=v.value;}}
        else {let shift=0;while(((mask>>shift)&1)===0)shift++;count=masked>>shift;}
        if(count*numValues>1000||byteCount!==null&&byteCount>end-p)throw Error('TAGX values budget');
        const values=[];if(byteCount!==null){const until=p+byteCount;while(p<until){const v=variable(b,p,until);p+=v.length;values.push(v.value);}if(values.length>1000)throw Error('TAGX values budget');}
        else for(let n=0;n<count*numValues;n++){const v=variable(b,p,end);p+=v.length;values.push(v.value);}
        tagMap[tag]=values;
      }
      if(table.length>=1000)throw Error('INDX entries budget');table.push({name,tagMap});
    }
  }
  return {table,cncx};
}

export function boundedPalmDOC(bytes) {
  const output=[];let i=0;
  while(i<bytes.length){const x=bytes[i++];
    if(x===0)output.push(0);
    else if(x<=8){if(i+x>bytes.length)throw Error('Truncated PalmDOC literal');output.push(...bytes.subarray(i,i+x));i+=x;}
    else if(x<=127)output.push(x);
    else if(x<=191){if(i>=bytes.length)throw Error('Truncated PalmDOC pair');const pair=(x<<8)|bytes[i++],distance=(pair&0x3fff)>>3,length=(pair&7)+3;
      if(!distance||distance>output.length)throw Error('Invalid PalmDOC distance');for(let j=0;j<length;j++)output.push(output[output.length-distance]);}
    else output.push(32,x^128);
    if(output.length>4096)throw Error('PalmDOC expansion budget');
  }
  return Uint8Array.from(output);
}
